#!/bin/bash -e

source .profile
check 'bosh env' 'Bosh Lite Director' true #> BOSH environment is not set.
check 'cf --version' 'cf version 6\.*' true #> Cloud Foundry CLI not installed or version outdated.
check 'cf target | grep --color=never "API endpoint"' '.*API version.*' true #> Cloud Foundry is not set or is set incorrectly.
check 'cf target | grep --color=never "User"' 'User:           admin' true #> You are not logged in with correct user.
