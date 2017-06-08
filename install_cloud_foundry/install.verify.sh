#!/bin/bash -e

check 'curl --connect-timeout 3 -I --silent http://api.bosh-lite.com/v2/info' 'HTTP/1\.1 200 OK' true #> Cf api should be avaliable.
