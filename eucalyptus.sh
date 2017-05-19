#!/bin/bash
# Copyright (c) Microsoft Corporation. All Rights Reserved.
# Licensed under the MIT license. See LICENSE file on the project webpage for details.

CURRENT_SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH="$CURRENT_SCRIPT_PATH/install.sh"

#sudo bash $SCRIPT_PATH -p "oxa/satyawams" -q "Microsoft" $@

sudo bash $SCRIPT_PATH $@

#sudo bash $SCRIPT_PATH -s dev $@
