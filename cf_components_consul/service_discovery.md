### Consul as a service discovery tool

Cloud Foundry is a large distributed system that is designed to be fault tolerant and highly available. That esentually means two things:
1. All CF components should be scaled to have at least 2 instances, to prevent having single point of failer.
2. If some instance of any component fails for some reason, all other components should handle it gracefylly and the system as a whole should still operate normaly.

In order to satisfy the second requirement we need to allow any component to enter or exit the cluster at any time and without a prior notification. This means that in order to connect some component together we can't rely on hardcoding one component's IP addresses in configuration of another component. Instead we need to rely on some Service Discovery tool, that will resolve service names to their curent IP addresses. That is one of the reasons of using Consul in Cloud Foundry deployment. Let's see how it works.

#### Scaling components

Our curent installation isn't actually highly available, because it uses Bosh Lite and is sutable only for educational or testin purposes. That's wny our installation have a single instance of all CF components. But in order to demostrate service discovery features it is better to scale some component. Let's scale `diego-cell` component (`diego-cell` is reponsible for actually running CF applications in a containers. We will discuss this component in more details later) We can do the scaling with the following opfile (You need to save it as `~/opfiles/scale-cell.yml`)

```file=~/opfiles/scale-cell.yml
- type : replace
  path: /instance_groups/name=diego-cell/instances
  value: 2
```

Now let's redeploy the CF

```exec
cd ~/cf-deployment
bosh -n -d cf deploy cf-deployment.yml -o operations/bosh-lite.yml -o ~/opfiles/scale-cell.yml --vars-store deployment-vars.yml -v system_domain=bosh-lite.com
```

#### Using Consul API

In order to use Consul the first thing you need to do is to ssh to one of the virtual machines.

```exec
bosh ssh diego-cell/0
```

There are actually two methods how you can work with consul: using CLI or triggereing API methods directly. You can find Consul CLI at the following location: `var/vcappackages/consul/bin` You can list all members of the cosul cluster using the following command:

```exec
cd /var/vcap/packages/consul/bin
./consul members 
```

Now let's try to access connsul API directly and list all services, that are registered with Consul 

```exec
sudo apt-get install jq
curl -s localhost:8500/v1/catalog/services | jq ""
```

We use `jq` command here to format json output. You might also noticed that we don't use any authentication to access Consul API. That is because Consul agent is running localy on each VM and Consul API is available only from this local machine. 

#### DNS resolution

In order to perform service discovery it is posible to use Consul Agent as a DNS server. If you look inside you `resolv.com` you will see that the first DNS server that is used is `127.0.0.1` and that is actually Consul agent.

```exec
cat /etc/resolv.com
```

This make posible to access any service like this:

```exec
sudo ping blobstore.service.cf.internal
```

#### Accessing multi instance services

But what is there are severl instances that provides some service? DNS resolution can be used in this case also. You remember that we previously scaled `diego-cell` component, so let's see how ip addresses for this service are resolved.

```exec
dig cell.service.cf.internal
```

You can see that answer section contains 2 IP addresses. Service consumer can use any of those, or use them in round robin way.

#### Using tags

Let's list services one more time.

```exec
curl -s localhost:8500/v1/catalog/services | jq ""
```
From the output of this command you can see that a service can contain optional tags. Those tags can be used as subdomains, for example:

```exec
dig z1.blobstore.service.cf.internal
```
This query should resolve all IP addresses from blobstore components deployed to `z1` availability zone

#### Health checks

Consul not only registers services and resolves their IP addressed. It is also responsible for monitoring therir health. Let's emulate service instance failier.
We are not in inside `diego-cell` instance and this instance registers `cell` service. It also have `rep` job that actually provides this service. So now we are going to stop this job.

```exec
sudo /var/vcap/bosh/bin/monit stop rep
```

Next we need to wait until the job is stopped. We can monitor the state of all jobs using the follwing command.

```exec
sudo /var/vcap/bosh/monit status
```

When `rep` job is stopped let's run

```exec
dig cell.service.cf.internal
```

Now you should see that only one IP address is returned. That is because by default Consul monitors the port that service is registered on. When this port becomes unavailable service goes to unhealthy state.It is also posible to write custom health check scripts  and provide them at service registration time. We can find a good example of such scrit on `blobstore` instance. Let's examine it.

```exec
exit #exiting from diego-cell instance
bosh ssh blobstore
``` 

First you need to check service registration scrip, you can find it here

```exec
cat /var/vcap/jobs/consul_agent/config/service-blobstore.json
```

From this service registration script you easily figure ou the location of the custom healthcheck script.

```exec
cat /var/vcap/jobs/blobstore/bin/dns_health_check
```

The script is pretty simple and you can read the comments to understand what exactly it does.
As a final step let's exit from VM.

```exec
exit
```
