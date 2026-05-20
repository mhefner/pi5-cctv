#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

if [[ "$CAM1_URL" == *"192.168.1.x"* ]] || [[ "$CAM2_URL" == *"192.168.1.x"* ]]; then
  echo "Error: edit config.env and set your real RTSP URLs before running."
  exit 1
fi

echo "Starting dual RTSP view (Ctrl+C to stop)..."
echo "  CAM1: $CAM1_URL  [${CAM1_W}x${CAM1_H}]"
echo "  CAM2: $CAM2_URL  [${CAM2_W}x${CAM2_H}]"

# SDL_VIDEODRIVER=kmsdrm forces SDL2 to use DRM/KMS output (no X11 needed).
# ffmpeg handles RTSP for both cameras, composites them, and displays via SDL2.
SDL_VIDEODRIVER=kmsdrm ffmpeg \
  -rtsp_transport tcp -i "$CAM1_URL" \
  -rtsp_transport tcp -i "$CAM2_URL" \
  -filter_complex \
    "[0:v]scale=${CAM1_W}:${CAM1_H}[l]; \
     [1:v]scale=${CAM2_W}:${CAM2_H}[r]; \
     [l][r]hstack=inputs=2[out]" \
  -map "[out]" \
  -f sdl2 "CCTV"
