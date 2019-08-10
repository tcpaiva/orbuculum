#!/bin/bash

if [[ $# -ne 2 ]] ; then
    echo "Usage: ${0} <Vivado version base dir> <target script>"
    exit 1
fi

if [ ! -d "${1}" ] ; then
    echo "Problem accessing Vivado directory."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="${SCRIPT_DIR}/build.tcl"

source ${1}/settings64.sh
vivado -mode batch -nojournal -nolog -notrace -source ${BUILD_SCRIPT} -tclargs ${2} 
