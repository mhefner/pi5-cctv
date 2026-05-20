#!/usr/bin/env bash
set -e

echo "Installing GStreamer packages..."
sudo apt update
sudo apt install -y \
  gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav

echo ""
echo "Done. Edit config.env with your RTSP URLs, then run: bash view.sh"
