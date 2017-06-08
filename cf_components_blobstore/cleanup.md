### Cleanup

Now let's do some cleanup: revert our installation to its original state and delete S3 bucket.

```exec
cd ~/cf-deployment
bosh -n -d cf deploy cf-deployment.yml -o operations/bosh-lite.yml --vars-store deployment-vars.yml -v system_domain=bosh-lite.com
source ~/vars
aws s3 rb --force s3://$BUCKET_NAME
```
