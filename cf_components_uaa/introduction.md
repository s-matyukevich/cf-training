### CloudFoundry User Account and Authentication (UAA) Server

The UAA is a multi tenant identity management service, used in Cloud Foundry, but also available as a stand alone OAuth2 server. It's primary role is as an OAuth2 provider, issuing tokens for client applications to use when they act on behalf of Cloud Foundry users. It can also authenticate users with their Cloud Foundry credentials, and can act as an SSO service using those credentials (or others). It has endpoints for managing user accounts and for registering OAuth2 clients, as well as various other management functions.
