### Using consul for obtaining distributed locks

When building a large dicstributed system the need in syncronizing components between each other always arizes. In Cloud Foundry case  syncronization is required for a lot of components. The most common example is a `diego-cell`: when some cell decides to run a particular application all other cells should not attempt to do this, this means that the first cell should obtain some kind of lock when starting running an application. The tricky  thing here is that the system that issues such locks should be distributed by itself and gracefully handles failers of its own instances. And even more: the system should handle situations when some component obtains a lock and then fails - the lock should be automaticaly release in such case.

Consul is a tool that satisfies all those criterias. For more information about how lock works in consul you can refer to the [official documentation](https://www.consul.io/docs/internals/sessions.html) 

#### Build your own lock with consul

Now let's try to emulat what Cloud Foundry is doing and areate your own lock using Consul API. This can be docne in a few steps. Befor we will be able to do this, lets ssh to some of the CF components VM.

```exec
bosh ssh diego-cell/0
```

1. [Create a new session](https://www.consul.io/docs/agent/http/session.html#session_create)
  ```exec
  session=$(curl -s -X PUT localhost:8500/v1/session/create | jq -r ".ID")
  ``` 

1. [Get session info](https://www.consul.io/docs/agent/http/session.html#session_info) 
  ```exec
  curl -s localhost:8500/v1/session/info/$session | jq ""
  ```
  This step is optional, we just want to execute it to ensure that session is successfully created and examine all session parameters.
  The following parameters have been applied to our session by default:
  *. Node: 'diego-cell-0'. This indicates that the session belongs to the current node
  *. Checks: `serfHealth`. No custom health checks were provided, so consul will use the default check to track whether curent node is healthy and will release the lock otherwise.
  *. TTL: `empty-string` The lock will never expire, no need to renew it. Usualy Cloud Foundry sets this parameter to some short period and the component, that obtains the lock periodicaly renews it. If the component fails to renew the lock - it is automatically released.
  *. Behavior: `release`  Release the lock on session invalidation. Alternatively can be `delete` with will delete the underlying key-value pair (more on that later)

1. [Put some key-value pair] (https://www.consul.io/docs/agent/http/kv.html#single) and aquire lock
  ```exec
  curl -s -X PUT localhost:8500/v1/kv/my-key?acquire=$session -d "some-data"
  ```
1. Verify that key-value pair is written
  ```exec
  curl -s localhost:8500/v1/kv/my-key | jq ""
  ```
  The value that you see in the output is base64 encoded string `some-data`

1. Try to create another session and aquire lock on the same key, while old lock is still held
  ```exec
  new_session=$(curl -s -X PUT localhost:8500/v1/session/create | jq -r ".ID")
  curl -s -X PUT localhost:8500/v1/kv/my-key?acquire=$new_session -d "some-other-data"
  ``` 
  This step is expected to fail and return false as the output.

1. Modify key using existing session
  ```exec
  curl -s -X PUT localhost:8500/v1/kv/my-key?acquire=$session -d "some-other-data"
  ```
1. Release the lock
  ```exec
  curl -s -X PUT localhost:8500/v1/kv/my-key?release=$session -d "some-other-data"
  ```
  Now any other session should be able to aquire the lock on the same key-pait
  
#### Examine existing sessions

You can easily examine what sessions are curently running in Consul using the following command:

```exec
curl -s localhost:8500/v1/session/list | jq ""
```

As you can see most of them have `TTL` field set, so the components that runs those sessions are required to renew their sessions periodically. 
Another usefull command is the one that allows you to list all existing keys

```exec
curl -s localhost:8500/v1/kv/?keys | jq ""
```

As usual let's exit the VM after we are done.

```exec
exit
```
