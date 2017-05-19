#!/bin/bash
# Copyright (c) Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT license. See LICENSE file on the project webpage for details.

CURRENT_SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH="$CURRENT_SCRIPT_PATH/install.sh"



#sudo bash $SCRIPT_PATH -b "open-release/ficus.master" $@

sudo bash $SCRIPT_PATH -b "open-release/ficus.master" -s dev $@
