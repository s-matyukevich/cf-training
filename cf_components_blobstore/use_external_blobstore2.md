### Use external blobstore (Part 2)

Now you are ready to create an opfile that will make necessary adjustments to the manifest. You should save this file as `~/opfiles/aws-blobstore.yml`

```file=~/opfiles/aws-blobstore.yml
- type: replace
  path: /instance_groups/name=api/jobs/name=cloud_controller_ng/properties/cc/buildpacks
  value:
    blobstore_type: fog
    buildpack_directory_key: {{ source vars && echo $BUCKET_NAME }}
    fog_connection: &fog_connection
      aws_access_key_id: {{cat ~/.aws/credentials | grep aws_access_key_id | awk '{print $3}'}}
      aws_secret_access_key: {{cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print $3}'}} 
      provider: AWS
      region: {{cat ~/.aws/config | grep region | awk '{print $3}'}} 
- type: replace
  path: /instance_groups/name=api/jobs/name=cloud_controller_ng/properties/cc/droplets
  value:
    blobstore_type: fog
    buildpack_directory_key: {{ source vars && echo $BUCKET_NAME }}
    fog_connection: &fog_connection
- type: replace
  path: /instance_groups/name=api/jobs/name=cloud_controller_ng/properties/cc/packages
  value:
    blobstore_type: fog
    buildpack_directory_key: {{ source vars && echo $BUCKET_NAME }}
    fog_connection: &fog_connection
- type: replace
  path: /instance_groups/name=api/jobs/name=cloud_controller_ng/properties/cc/packages
  value:
    blobstore_type: fog
    buildpack_directory_key: {{ source vars && echo $BUCKET_NAME }}
    fog_connection: &fog_connection
```

If you are interested in more details about different posible ways of configureing blobstore, you can refer to [official documentation](https://docs.cloudfoundry.org/deploying/common/cc-blobstore-config.html)

Having this opfile in place we are ready to redeploy our CF using AWS S3 blobstore.

```exec
cd ~/cf-deployment
bosh -n -d cf deploy cf-deployment.yml -o operations/bosh-lite.yml -o ~/opfiles/aws-blobstore.yml --vars-store deployment-vars.yml -v system_domain=bosh-lite.com
```

After your deployment is finished you can check the content of your bucket and ensure that it is not empty.

```exec
source ~/vars
aws s3 ls s3://$BUCKET_NAME
```
