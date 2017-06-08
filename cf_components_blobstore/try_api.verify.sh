#!/bin/bash -e

export port=4443
export user="blobstore-user"
export pass=$(cat ~/cf-deployment/deployment-vars.yml | shyaml get-value blobstore_admin_users_password)
export read_url=$(curl -s --cacert ~/certs/blobstore-ca.pem --user $user:$pass "https://blobstore.service.cf.internal:$port/sign?path=/some-key&expires=16730564099")
export md5=$(echo $read_url | grep -oP 'md5=\K.*(?=&)')
export expires=$(echo $read_url | grep -oP 'expires=\K.*')
check 'curl -s --cacert ~/certs/blobstore-ca.pem "https://blobstore.service.cf.internal:$port/read/some-key?md5=$md5&expires=$expires"' 'some-data' true #> Unable to read data from blobstore using internal url 

export port=4443
export user="blobstore-user"
export pass=$(cat ~/cf-deployment/deployment-vars.yml | shyaml get-value blobstore_admin_users_password)
export read_url=$(curl -s --cacert ~/certs/blobstore-ca.pem --user $user:$pass "https://blobstore.service.cf.internal:$port/sign?path=/some-key&expires=16730564099")
export md5=$(echo $read_url | grep -oP 'md5=\K.*(?=&)')
export expires=$(echo $read_url | grep -oP 'expires=\K.*')
check 'curl -s "http://blobstore.bosh-lite.com/read/some-key?md5=$md5&expires=$expires"' 'some-data' true #> Unable to read data from blobstore using external url 
