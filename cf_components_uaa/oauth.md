### Undertanding OAuth protocol

UAA API implements [OAuth 2 protocol](https://oauth.net/2/). OAuth (Open Authorization) is an open standard for token-based authentication and authorization on the Internet. OAuth,  allows an end user's account information to be used by third-party services, such as Facebook, without exposing the user's password. Fo those of you who are not familiar with this protocol I recommed to read the following [article](https://aaronparecki.com/oauth-2-simplified/) which explains this protocol in simplified manner.

#### Why do Cloud Foundry need OAuth?

The common use case for OAuth protocol is authorizing some third party application to execute some actions on user'a behalf (for example read my FAcebook account information in order to collect my personal data) In Such case I as a user don't want to provide third party application with my account credentialsa, Instead OAuth protocol is used to authorize the application to do only for reading my personal data.
Ok, but how all of this is applied to Cloud Foundry and UAA? Seems like when working wtth CF CLI I don't have any benefits from using OAuth, right?  Well, thae answer can be found if you look on some common UAA usecases:

1. UAA is designed not only to be used to authenticate user to use CF API. Applications, deployed to CF are encouraged to use UAA for authenticating there usres. Some of those applications can benefit from being able to implement OAuth authorization workflow.
1. Some of the applications, deployed to CF, can also use CF API. (There are a lot of examples of such applications: anything that scales another apps, or provide some UI for managing your CF resources) In such case it is common to authorize application to have limited access to CF API, instead of providing it with CF credentials.

Another thing to consider in regarding to using Oauth is security: if we treat each CF component as individual OAuth client with it's own authorized scope, by hacking a single component an attacker will not be able to get access to the whole system.

#### OAuth clients

Each CF component, that need to interact with UAA should register it's own OAuth client. Default clients are registered in the manifest. You can find client registrations section in `instance_groups/name=uaa/properties/uaa/clients` section. It should look like the following:

```exec
clients:
  cc-service-dashboards:
    authorities: clients.read,clients.write,clients.admin
    authorized-grant-types: client_credentials
    scope: openid,cloud_controller_service_permissions.read
    secret: "((uaa_clients_cc-service-dashboards_secret))"
  cc_routing:
    authorities: routing.router_groups.read
    authorized-grant-types: client_credentials
    secret: "((uaa_clients_cc-routing_secret))"
  cf:
    access-token-validity: 600
    authorities: uaa.none
    authorized-grant-types: password,refresh_token
    override: true
    refresh-token-validity: 2592000
    scope: cloud_controller.read,cloud_controller.write,openid,password.write,cloud_controller.admin,scim.read,scim.write,doppler.firehose,uaa.user,routing.router_groups.read,routing.router_groups.write
  cloud_controller_username_lookup:
    authorities: scim.userids
    authorized-grant-types: client_credentials
    secret: "((uaa_clients_cloud_controller_username_lookup_secret))"
  doppler:
    authorities: uaa.resource
    override: true
    authorized-grant-types: client_credentials
    secret: "((uaa_clients_doppler_secret))"
  gorouter:
    authorities: routing.routes.read
    authorized-grant-types: client_credentials,refresh_token
    secret: "((uaa_clients_gorouter_secret))"
  ssh-proxy:
    authorized-grant-types: authorization_code
    autoapprove: true
    override: true
    redirect-uri: "/login"
    scope: openid,cloud_controller.read,cloud_controller.write
    secret: "((uaa_clients_ssh-proxy_secret))"
  tcp_emitter:
    authorities: routing.routes.write,routing.routes.read,routing.router_groups.read
    authorized-grant-types: client_credentials,refresh_token
    secret: "((uaa_clients_tcp_emitter_secret))"
  tcp_router:
    authorities: routing.routes.read,routing.router_groups.read
    authorized-grant-types: client_credentials,refresh_token
    secret: "((uaa_clients_tcp_router_secret))"
```

When looking on that registration, many people ask: what is the difference between `scope` and `authorities` sections? The answer is that clients that uses `client_credentials` grant type (the ones that authenticate with UAA directly, without user participation) speify `authorities` parameters. The content of the `authorities` section will be included in the token, that is issued for such kind of clients. You can think about `authorities` section as the roles, that are assigned to the client itself.
Another type of clients (for example `cf` client, that is used by CF CLI) specify `scope` parameter. The resulting token, that UAA would create for such kind of client will not necessare contain all parameters that are defined in `scope` - only those, that current user have. You can think about `scope` parameter as the permission, that the client asks user to share.
The distinction what type of authorization UAA should perform is made based on the value of `grant_type` parameter, that is passed to UAA in the authentication request.

#### Implementing OAuth authorization flow

It is posible to register new clients dynamically, using UAA API. Let's do this and see how we can implement OAuth authorization flow using our custom client.

1. Obtain admin client secret
  ```exec
  admin_secret=$(cat ~/cf-deployment/deployment-vars.yml | shyaml get-value uaa_admin_client_secret)
  ```
  Don't confuse this value with admin user password. Admin user (that we use to work with CF API) and admin client (that we use to work with UAA API) are different entities. WE need admin client secret to authorize oursef to create new clients (in order to do this we need to have `uaa.admin` scope in our token)

1. Get access token
  ```exec
  output=$(curl -s --cacert ~/certs/router-ca.pem -d "grant_type=client_credentials" --user admin:$admin_secret https://uaa.bosh-lite.com/oauth/token)
  echo $output | jq ""
  access_token=$(echo $output | jq -r ".access_token")
  ```

1. Register new client
  ```exec
  curl -s --cacert ~/certs/router-ca.pem \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d '{
      "client_id" : "my-client",
      "name" : "My client name",
      "client_secret" : "my-client-secret", 
      "scope" : ["some-scope"],
      "authorized_grant_types" : ["authorization_code"]
    }' \
    https://uaa.bosh-lite.com/oauth/clients | jq ""
  ```
  A few of the provided parameters needs additional explanation:
  *. `scope` - As you can see clients can create their own scopes. It is up to client application to interpret the meaning of the scope. 
  *. 
