### What is the Blobstore?

The Blobstore is a CF component that is responsible for storing large blobs of data. Here Cloud Foundry stores packages with application source code, droplets (result of application compilation) and some other large files.

In the default CF installation blobstore is deployed to a single VM. Let's go inside this VM and see how it works.

```exec
bosh ssh blobstore
cd /var/vcap/jobs
ls
```

Now you can see what jobs are deployed to this VM. `consul_agent`, `metron_agent` and `route_registrar` are standard jobs that are deployed to almost all VMs and we will cover them in a later lessons. But what we are interested  in is the `blobstore` job.

Let's open a `monit` file for blobstore. (For more information about how BOSH uses monit, please refer to `Create BOSH release` lesson. Also you can look into [monit documentation](https://mmonit.com/monit/documentation/) )

```exec
cd blobstore
cat monit
```

If you want to see more detail about processes, that monit watches, you can execute the following command.

```exec
sudo /var/vcap/bosh/bin/monit status
```

From monit control file you can learn that job `blobstore` consists of two processes: `blobstore_nginx` and `blobstore_url_signer` Let's examine the first one and open control file for this process.

```exec
cat bin/nginx_ctl
```

It is easy to see that when this file is executed with `start` parameter (and that is exactly what monit does for us) it just starts [nginx](https://www.nginx.com/) and  configure it with a proper onfig file. (Actually it also responsible for monitoring pid file and saving process output into log directory, but that details are not important for us now) Next logical step is to check what is inside nginx config file

```exec
cat config/nginx.conf
```

Nothing very interesting so far. This file just configures some global nginx settings like mime types, log format and location and some others. But at the bottom we can see that it also includes configuration files from `var/vcap/jobs/blobstore/config/sites/` directory, and that is the exact place where main confguration is sotred. Let's check it out.

```exec
cat config/sites/blobstore.conf
```

As this file is pretty large, you probably would like to use `cat config/sites/blobstore.conf | less` command instead, or any other methods that you prefer to use for reading files from terminal.

From the config file you can see that two servers are defined: internal and public. Both of them contains `/read` and `/write` methods, that are equals for both servers. Internal server also contains `/admin` and `/sign` methods. Internal server is esigned to be accessible only by other CF components using `https://blobstore.service.cf.internal` (all subdomains of `cf.internal` domain are resoled by consul. We will conver how this works later)  Public server is accessible by `https://blobstore.<sustem-domain> url  or in our case by `https://blobstore.bosh-lite.com` It is Cloud Foundry router that is responsible for forwarding all requests send to `blobstore` subdomain to apropriate port on the blobstore VM. We will talk about it in more details when we discuss cf router component. 

Blobstore uses standard [WebDAV protocol](https://en.wikipedia.org/wiki/WebDAV) it is implemented by [webdav nginx module](http://nginx.org/en/docs/http/ngx_http_dav_module.html) 

You mught wonder why do we need a public server? Why it is not ehough to use only internal one? The answer if that Cloud Foundr API have some methods that actually redirects user to blobstore public server. A good example is [Downloads the bits for an App](https://apidocs.cloudfoundry.org/252/apps/downloads_the_bits_for_an_app.html) method.

Ok, but how we then protect public server from unauthorized access? And that is where signing comes into play. Basically the process is the following:
1. Any CF component, that wants to provide public access to blobstore should call sign method first. This method is available only from internal server.
2. Sign method takes url and expiration date as an input and uses a private secret to generate signature. This signature is attached to the url
3. Public server verifies expiration date and signature before providing access to its data.
Additionaly all trafic to internal server is protected by using SSL and `sign` method is also protected by basic authentication.

Finally let's exit fomr blobstore VM
```exec
exit
```
