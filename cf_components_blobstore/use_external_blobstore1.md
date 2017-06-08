### Use external blobstore (Part 1)

Ok, now you should have a solid knoledge about blobstore architecture and API. But there are still some open questions. How to configure other components to use blobstore? Andwhat about high availability, is it posible to store our blobs in more reliable place than filesystem of the blobstore VM? 

We will try to answer those questions shourtly.

First of all, let's examine our manifest and find a place, where we provide other components with blobstore address and credentials. You can serch your manifest and find lines similar to the following:

```
buildpacks: &blobstore-properties
  blobstore_type: webdav
  webdav_config:
    ca_cert: "((blobstore_tls.ca))"
    blobstore_timeout: 5
    password: "((blobstore_admin_users_password))"
    private_endpoint: https://blobstore.service.cf.internal:4443
    public_endpoint: https://blobstore.((system_domain))
    username: blobstore-user
```

Here we specify blobstore type (webdav in our case) and provide blobstore credentials so that other components can connect to the blobstore. We also save this configuration in a yml anchor `blobstore-properties` so we can easily reuse it in different places of the manifest.

Now let's try to make our blobstore more reliable and use AWS S3 storage instead of the file system. But before we will be able to do this we need to install AWS CLI and create a bucket here. You can do this with the following commands.

```exec
sudo apt-get install unzip python-dev  -y
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
rm awscli-bundle* -rf
```

Then you need to configure your aws cli and provide AccessKey, SecretKey and default region (for example, `us-west-1`). 
```
aws configure
```

Next you can create the bucket and save its name for future use.

```exec
export BUCKET_NAME=cf-training$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1)
aws s3 mb s3://$BUCKET_NAME
cat > ~/vars <<EOF
export BUCKET_NAME=$BUCKET_NAME
EOF
chmod +x vars
```

