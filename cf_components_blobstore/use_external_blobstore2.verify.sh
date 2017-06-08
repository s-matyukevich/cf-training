#!/bin/bash -e

check 'cat ~/opfiles/aws-blobstore.yml' 'blobstore' true #> aws-blobstore opfile not found.

source ~/vars
check 'aws s3 ls s3://$BUCKET_NAME' '^$' false #> Blobstore bucket is empty 
