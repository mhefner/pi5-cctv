#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

# Validate URLs are set
if [[ "$CAM1_URL" == *"192.168.1.x"* ]] || [[ "$CAM2_URL" == *"192.168.1.x"* ]]; then
  echo "Error: edit config.env and set your real RTSP URLs before running."
  exit 1
fi

# Auto-detect best available decoder: hardware > openh264 > fail with hint
if gst-inspect-1.0 v4l2h264dec &>/dev/null; then
  DECODER="v4l2h264dec"
  echo "Using hardware decoder (v4l2h264dec)"
elif gst-inspect-1.0 openh264dec &>/dev/null; then
  DECODER="openh264dec"
  echo "Using software decoder (openh264dec)"
else
  echo "Error: no H.264 decoder found. Run: sudo apt install gstreamer1.0-plugins-bad"
  exit 1
fi

echo "Starting dual RTSP view (Ctrl+C to stop)..."
echo "  CAM1: $CAM1_URL  [${CAM1_W}x${CAM1_H} at ${CAM1_X},${CAM1_Y}]"
echo "  CAM2: $CAM2_URL  [${CAM2_W}x${CAM2_H} at ${CAM2_X},${CAM2_Y}]"

gst-launch-1.0 -e \
  compositor name=comp \
    sink_0::xpos="$CAM1_X" sink_0::ypos="$CAM1_Y" sink_0::width="$CAM1_W" sink_0::height="$CAM1_H" \
    sink_1::xpos="$CAM2_X" sink_1::ypos="$CAM2_Y" sink_1::width="$CAM2_W" sink_1::height="$CAM2_H" \
  ! kmssink sync=false \
  rtspsrc location="$CAM1_URL" latency=100 protocols=tcp \
    ! rtph264depay ! h264parse ! "$DECODER" \
    ! videoconvert ! videoscale \
    ! "video/x-raw,width=$CAM1_W,height=$CAM1_H" ! comp.sink_0 \
  rtspsrc location="$CAM2_URL" latency=100 protocols=tcp \
    ! rtph264depay ! h264parse ! "$DECODER" \
    ! videoconvert ! videoscale \
    ! "video/x-raw,width=$CAM2_W,height=$CAM2_H" ! comp.sink_1
