#!/bin/sh
# Copies rendered brand assets into platform folders (macOS `sips`).
set -e
ICON=assets/branding/icon_1024.png
LOGO=assets/branding/splash_logo.png
R=android/app/src/main/res
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d=${pair%%:*}; px=${pair##*:}
  sips -z $px $px "$ICON" --out "$R/mipmap-$d/ic_launcher.png" >/dev/null
done
for pair in mdpi:144 hdpi:216 xhdpi:288 xxhdpi:432 xxxhdpi:432; do
  d=${pair%%:*}; px=${pair##*:}
  sips -z $px $px "$LOGO" --out "$R/mipmap-$d/launch_image.png" >/dev/null
done
I=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in "$I"/*.png; do
  px=$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')
  sips -z $px $px "$ICON" --out "$f" >/dev/null
  # App Store icons must not contain alpha.
  sips -s format jpeg "$f" --out /tmp/_icon.jpg >/dev/null && sips -s format png /tmp/_icon.jpg --out "$f" >/dev/null
done
L=ios/Runner/Assets.xcassets/LaunchImage.imageset
sips -z 144 144 "$LOGO" --out "$L/LaunchImage.png" >/dev/null
sips -z 288 288 "$LOGO" --out "$L/LaunchImage@2x.png" >/dev/null
sips -z 432 432 "$LOGO" --out "$L/LaunchImage@3x.png" >/dev/null
echo "Brand assets applied."
