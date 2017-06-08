#!/bin/bash -e

check 'aws ec2 describe-regions' '.*AWS was not able to validate the provided access credential.*' false #> AWS credentialls should be entered correctly

source vars
check 'echo $BUCKET_NAME' 'cf-training' true #> Bucket name isn't saved to environment
