#!/usr/bin/env sh

echo "Needs super user permission:"
sudo echo "Okay good!"
swift build -c release
sudo cp -L .build/release/cloudAutoUploader /usr/local/bin/
