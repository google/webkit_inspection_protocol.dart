#!/bin/bash

# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Verify that the libraries are error free.
pub global activate tuneup
pub global run tuneup check

# Install CHROMEDRIVER
export CHROMEDRIVER_BINARY=/usr/bin/google-chrome
export CHROMEDRIVER_OS=linux64
export CHROME_LATEST_VERSION=$("$CHROMEDRIVER_BINARY" --version | cut -d' ' -f3 | cut -d'.' -f1)
export CHROME_DRIVER_VERSION=$(wget -qO- https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_LATEST_VERSION)
wget https://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_$CHROMEDRIVER_OS.zip
unzip "chromedriver_${CHROMEDRIVER_OS}.zip"
export CHROMEDRIVER_ARGS=--no-sandbox
export PATH=$PATH:$PWD

# Run tests
pub run test -j 1
