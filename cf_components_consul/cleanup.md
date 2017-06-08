### Cleanup

Now let's revert our installation to its original state.

```exec
cd ~/cf-deployment
bosh -n -d cf deploy cf-deployment.yml -o operations/bosh-lite.yml --vars-store deployment-vars.yml -v system_domain=bosh-lite.com
```
