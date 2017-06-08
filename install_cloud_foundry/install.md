### Install

With new BOSH 2.0 features the process of Cloud Foundry installation becomes extremly easy. you need to do the following steps:

1. Install git
  ``` exec
  sudo apt-get update
  sudo apt-get install -y git
  ```

1. Clone `cf-deplyment`repository
  ``` exec
  git clone  https://github.com/cloudfoundry/cf-deployment/
  cd cf-deployment
  git checkout master
  ```

1. Update Director `cloud-config` to use default cloud-config that comes with cf-deployment.
  ```exec
  bosh -n update-cloud-config ~/cf-deployment/bosh-lite/cloud-config.yml
  ``` 
  Let's take a quick look on the sections, defined in this file
  * 'azs' - here we define 3 availability zones. For BOSH Lite deployng in several availability zones don't make much sense, because underlying CPI just ignores avz setting. But we wtill need to define availability zones, because default manifest uses highly available deployment.
  * `compilation` - settings that will be applided for compilation  VMs (in case of BOSH Lite for compilation containers)
  * `disk_types` - different types of persistent disks.
  * `networks` - here we define single manual network. BOSH Lite simulate networking by creating virtual network with `10.244.0.0/22` range. Each container receives an IP address in those network. Host machine can also connect to this network by using special virtual network interface.  
  * `vm_extensions` - VM extension is a named Virtual Machine configuration in the cloud config that allows to specify arbitrary IaaS specific configuration such as associated security groups and load balancers. Here we just define vm_extensions that are used in the deployment manifest.
  * `vm_types` - ilst of all posible virtual machine types. In BOSH Lite all those VMs are mapped to a containers and all containers have the same configuration and don't have any resource limits. But we wtill need to define all posible vm types, that are used in the default manifest. 

1. Upload stemcell
  ```exec
  bosh upload-stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent?v=3363.9
  ```

1. Deploy
  ```exec
  cd ~/cf-deployment
  bosh -n -d cf deploy cf-deployment.yml -o operations/bosh-lite.yml --vars-store deployment-vars.yml -v system_domain=bosh-lite.com
  ```
  `cf-deployment.yml` is a default Cloud Foundry manifest. We will take a locser look on its content later, when talking about CF componennts.
  `opsfiles/bosh-lite.yml` is an opsfile that contains all bosh-lite specific changes to the default manifest. This includes updating private ip addresses, scaling deployment down to use single availability zone and adding bosh lite specific security groups to prevent unauthorized access from CF containers.
  `deployment-vars.yml` is a file that contains all properties, needed by the manifest.On the first run values for such properties as passwords or ssl certificates will be generated and saved in this file.
  `system_domain=bosh-lite.com` - here we define the only property that can't be generated: `system_domain`

1. Access CF API
  Now let's check whether our CF API is available. In order to be able to do this we need to parse `deployment-vars.yml ` file and find the values for router CA certificate.
  ```exec
  curl -k  https://api.bosh-lite.com/v2/info 
  ```

1. Save deployment name to environment variable so we don't need to repeat it in the future

```exec
cat >> ~/.profile <<EOF
export BOSH_DEPLOYMENT=cf
EOF
source ~/.profile
```
