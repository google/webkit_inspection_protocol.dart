#!/bin/bash

# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Verify that the libraries are error free.
pub global activate tuneup
pub global run tuneup check

# Temporarily disabled due to issues/24
# /usr/bin/chromium-browser --no-sandbox --remote-debugging-port=9222 &
# pub run test -j 1
