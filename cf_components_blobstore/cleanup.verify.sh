#!/bin/bash -e

source ~/vars
check 'aws s3 ls' "$BUCKET_NAME" false #> cf_training bucket is not deleted
source .profile
check 'bosh download-manifest' 'webdav' true #> CF installation should be rolled back to use webdav blobstore
