### Authentication process

The first thing we are going to do is to see how Cloud Foundry CLI authenticates uses using UAA. There is very usefull environment varialbe that will help us to do so (CF_TRACE) Setting this variable to `true` tels the CLI to print all requests that it executes to stdout. Also we need to obtain admin password from `deployemnt-vars.yml` before we will be able to authenicate ourselves.

```exec
admin_password=$(cat ~/cf-deployment/deployment-vars.yml | shyaml get-value uaa_scim_users_admin_password)
CF_TRACE=true cf auth admin $admin_password
```

By examinig the output of the last command you can easily understand what commands the CLI issues to authenificate the user. 

#### Login with UAA

1. Made some preparations (install `jq` and  obtain CA cert from the router)
  ```exec
  sudo apt-get install jq
  cat ~/cf-deployment/deployment-vars.yml | shyaml get-value router_ca.ca > ~/certs/router-ca.pem
  ```
  You may why do we need route CA, while we are going to talk with UAA? That is because all requests for all public facing components are resolved by the router. 

1. Get login information. 
  ```exec
  curl -s --cacert ~/certs/router-ca.pem https://uaa.bosh-lite.com/login -H "Accept: application/json" | jq ""
  ```
  This endpoint returns login information: what input should the CLI asks from a user. We use `Accept: application/json` header here because the same enpoint is used for a web based version of login, so by default it returned HTML instead of json. From the output you can see that user email and password should be provided for outhentication.

1. Get authentication token
  ```exec
  output=$(curl -s --cacert ~/certs/router-ca.pem -d "grant_type=password&password=$admin_password&scope=&username=admin" --user cf: https://uaa.bosh-lite.com/oauth/token)
  echo $output | jq ""
  access_token=$(echo $output | jq -r ".access_token")
  refresh_token=$(echo $output | jq -r ".refresh_token")
  ```
  You may ask why do we need to provide credentials for Basic Authnetication (`--user cf:`) ? That is because UAA OAuth protocol to authenticate users. It actually don't authenticate user directly, instead it authnticates `cf` oauth client to do some operations on behalf of user `admin`. We will talk about why this is needed and about OAuth in general shourtly. 
  The output has the following fields, that are important for us:
  *. `scope`:  You can think about scopes as a kind of roles that current user have. Scopes distinguishes what kind of operations are allowd for user to execute. UAA itself don't attach any meaning to sopes, it is responsibility of other components to allow or disallow some actions for current user based on his scipe.
  *. `access_token`: Token that should be attached to all further requiests. We will look on how other components use that token shourtly.
  *. `expires_in`: Lifetime for the access token. After this amount of seconds the token is expired and must be refreshed.
  *. `refresh_token`: Another token that is used for refreshing access_token.

#### How tokens are used?

Ok, now that we have token let's try to execute some API call that requires authentication.

```exec
curl -s --cacert ~/certs/router-ca.pem https://api.bosh-lite.com/v2/organizations -H "Authorization: Bearer $access_token"
```
As you can see we attach the token inside `Authorization` header of the requiest.

Ok, but how Cloud Foundry API server validates that token? Does it need to contact UAA in order to do this? Actually the answer is NO. Token validation works in a different way. When we deploy the CF we specify two parameters: `jwt.signing_key` and `jwt.verification_key`. This is just a standart private/public key pair. UAA sign the token using `signing_key`. All other components are provided with `verification_key` that is used to decode and validate the token. Now let's try to decode the token manually o see what information is contained inside it.

1. Save verification key
  ```exec
  cat ~/cf-deployment/deployment-vars.yml | shyaml get-value uaa_jwt_signing_key.public_key > ~/certs/jwt-verification-key.pub
  ```

1. Split and decode the token
  ```exec
  IFS='.' read -ra tokens <<< "$access_token"
  header=$(echo ${tokens[0]} | base64 -d)
  body=$(echo ${tokens[1]} | base64 -d)
  signature=${tokens[2]}
  ```   
  The following command can complain about invalid input, but that is because tokens are not propely padded. It is safe to just ignore that error
  UAA token consits of 3 parts: header, body and signature. All 3 parts are separated by `.` and base64 encoded. The previous script splits the token and decodes its' parts.

1. Review  header and body
  ```exec
  echo $header | jq ""
  ```
  From header we can find out what algorithm was used to generate signature. Most likely that would be `RS256` That is important because we ned to use the same algorithm for verifying token signature.

  ```exec
  echo $body | jq ""
  ```
  Body of the token contains all required information about authenticated used. The most inportant field here is `scope` array. Based on its value the application can decide what operations are allowed for the user. We will talk about oauth scopes in details a bit later, but for now you can think of them like roles assigned to the user.
  
1. Verify token signature
  ```exec
  echo -n $signature | sed "s/-/+/g" | sed "s#_#/#g" | base64 -d > signature.txt
  echo -n "${tokens[0]}.${tokens[1]}" > in.txt
  openssl dgst -sha256 -verify ~/certs/jwt-verification-key.pub -signature signature.txt in.txt
  ```
  You should see `Verified OK` message. You may wonder why do we replace some cahracters in signature, before docuding it? That is because `base64` programm and java impalmentation of base64 algorithm uses different versions of base64 encoding specification.

#### Refresh token

As you might see from the decoded body of access token, by default tokens have short lifetime. That is actually makes a perfect sense, because if you issue a token for some user, and then cheange some permissions for that youser - your changes won't be applied until the old token will expire. That is because all information, required to quthorize the user is incoded in the token itself.
Another thing is that we don't want to ask user to enter his credential each time the token is expired. That's why refresh tochen mechnizm was introduced. Each time CF cLI recevis unauthorized responce it is first tries to refresh old access token using refresh token. We already have refresh token saved in environment variable, so now let's try to use it.
  ```exec
  curl -s --cacert ~/certs/router-ca.pem -d "grant_type=refresh_token&refresh_token=$refresh_token&scope=" --user cf: https://uaa.bosh-lite.com/oauth/token | jq ""
  ```
  So here we obtained new access token without providing user credentials, but using refresh token instead.
