#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

if [[ "$CAM1_URL" == *"192.168.1.x"* ]] || [[ "$CAM2_URL" == *"192.168.1.x"* ]]; then
  echo "Error: edit config.env and set your real RTSP URLs before running."
  exit 1
fi

# Returns the GStreamer depay+parse+decode chain for a given codec
decode_chain() {
  local codec="$1"
  if [[ "$codec" == "h265" ]]; then
    if gst-inspect-1.0 v4l2slh265dec &>/dev/null; then
      echo "rtph265depay ! h265parse ! v4l2slh265dec"
    elif gst-inspect-1.0 libde265dec &>/dev/null; then
      echo "rtph265depay ! h265parse ! libde265dec"
    else
      echo "Error: no H.265 decoder found. Run: sudo apt install gstreamer1.0-plugins-bad" >&2
      exit 1
    fi
  else
    if gst-inspect-1.0 openh264dec &>/dev/null; then
      echo "rtph264depay ! h264parse ! openh264dec"
    elif gst-inspect-1.0 avdec_h264 &>/dev/null; then
      echo "rtph264depay ! h264parse ! avdec_h264"
    else
      echo "Error: no H.264 decoder found. Run: sudo apt install gstreamer1.0-plugins-bad" >&2
      exit 1
    fi
  fi
}

CAM1_DECODE=$(decode_chain "${CAM1_CODEC:-h264}")
CAM2_FPS="${CAM2_FPS:-25}"

echo "CAM1 [${CAM1_CODEC:-h264}]: $CAM1_DECODE"
echo "CAM2 [${CAM2_CODEC:-h265}]: ffmpeg → FIFO → GStreamer (${CAM2_FPS}fps)"
echo "Starting dual RTSP view (Ctrl+C to stop)..."

# Named FIFO for raw I420 frames from CAM2.
# Open read-write (<>) so filesrc can open for reading without blocking
# (a FIFO read-open blocks until a writer exists; <> avoids that).
FIFO=/tmp/pi5cctv_cam2.fifo
rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

ffmpeg -y -rtsp_transport tcp -i "$CAM2_URL" \
  -vf "scale=${CAM2_W}:${CAM2_H}" \
  -f rawvideo -pix_fmt yuv420p \
  "$FIFO" 2>/dev/null &
FFMPEG_PID=$!

cleanup() {
  kill "$FFMPEG_PID" 2>/dev/null || true
  rm -f "$FIFO"
}
trap cleanup EXIT TERM INT

gst-launch-1.0 -e \
  compositor name=comp \
    sink_0::xpos="$CAM1_X" sink_0::ypos="$CAM1_Y" sink_0::width="$CAM1_W" sink_0::height="$CAM1_H" \
    sink_1::xpos="$CAM2_X" sink_1::ypos="$CAM2_Y" sink_1::width="$CAM2_W" sink_1::height="$CAM2_H" \
  ! kmssink sync=false \
  rtspsrc location="$CAM1_URL" latency=200 \
    ! $CAM1_DECODE \
    ! videoconvert ! videoscale \
    ! "video/x-raw,width=$CAM1_W,height=$CAM1_H" ! comp.sink_0 \
  filesrc location="$FIFO" \
    ! "video/x-raw,format=I420,width=$CAM2_W,height=$CAM2_H,framerate=$CAM2_FPS/1" \
    ! videoconvert ! comp.sink_1
