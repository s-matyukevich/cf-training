#!/bin/bash -e

source .profile
check 'bosh env' 'Bosh Lite Director' true #> BOSH environment is not set.
