# StoreBroker PowerShell Module
## REST Proxy Service

This covers the technical information around the REST Proxy service
and its implementation.  This document is aimed at those who need to
run and/or maintain the REST Proxy service; users that simply want to
_use_ the REST Proxy need only read
[Authentication With The Proxy](SETUP.md#authenticating-with-the-proxy).

----------
#### Table of Contents

*   [Overview](#overview)
*   [Client Id and Secret](#client-id-and-secret)
*   [High Level Design](#high-level-design)
    *   [WebApiConfig](#webapiconfig)
    *   [RootController](#rootcontroller)
    *   [ProxyManager](#proxymanager)
    *   [AsyncLock](#asynclock)
    *   [StartUp Tasks](#startup-tasks)
*   [Nonrepudiation](#nonrepudiation)
*   [Deployment](#deployment)
    *   [Production vs Staging](#production-vs-staging)
    *   [Process](#process)
    *   [ExpressRoute](#expressroute)
        *   [Classic vs ARM](#classic-vs-arm)
        *   [Configuration](#configuration)
    *   [Remote Desktop](#remote-desktop)
    *   [Endpoint JSON Configuration](#endpoint-json-configuration)
    *   [Maintenance Items](#maintenance-items)
        *   [Service Account Password](#service-account-password)
        *   [Authentication Certificate](#authentication-certificate)
        *   [SSL Certificate](#ssl-certificate)
        *   [Client Secrets](#client-secrets)
        *   [A RECORD](#a-record)
*   [Development](#development)
*   [StoreBroker Impact](#storebroker-impact)
*   [Using the Proxy with Other API Clients](#using-the-proxy-with-other-api-clients)
*   [References](#references)

----------


## Overview

The Windows Store Submission API is great, but it requires authentication with a Client ID and
Secret.  The creation of these is non-trivial (requires access to your company's Azure Active
Directory) if you want to ensure that you have unique logins for every user, and there is no
secure way to store the Client Secret if you want to use StoreBroker on a build machine to
automatically execute commands against the Store (like flighting of nightly builds).

The REST Proxy is designed to work around those issues by securely storing the Client Secret
in Azure, and then exposing its own REST API endpoint that clients can use identically
to the real Submission REST API, but it authenticates using Active Directory Security Groups which
are super-easy to manage and solve the authentication problem. 

----------

## Client Id and Secret

The REST API authenticates by using a "client id" and "client secret" pair.  These come from
"Web Applications" that you add to your Active Directory.  For more info on how these are created,
refer to [Getting Credentials](SETUP.md#getting-credentials).

In order for the proxy to work, it will be using two pairs of client id/secrets: one for access to
the PROD endpoint, and one for the INT endpoint. All PROD (or INT) requests will be authenticated
with the same client id/secret.  We are using
[Active Directory Security Groups](https://technet.microsoft.com/en-us/library/cc960640.aspx)
to protect the REST Proxy itself.

The PROD and INT Client Id's and secrets are stored in
`AzureService\ServiceConfiguration.Cloud.cscfg`.  The Client Secrets should be stored
 in encrypted form **and should never be stored directly in the code** for security purposes.

> Be aware that the Client Secrets have an expiration time of either 1 or 2 years (depending on
> how they are configured).  The steps for updating the service when this expiration occurs are
> covered [here](#client-secrets).

----------

## High Level Design

There are four main classes to be aware of:
   * `WebApiConfig` - determines our routing
   * `RootController` - processes the incoming request
   * `ProxyManager` - does the actual communication with the Windows Store Submission API
   * `AsyncLock` - a custom, specialized lock that works with asynchronous mehods.

### WebApiConfig

The overall goal was to make this Proxy be as resilient to future API changes as possible, and
thus require as little maintenance as possible.  To that end, this abuses ASP.NET WebApi
a little bit.

ASP.NET WebApi has the concept of "routing" and "controllers".  You create a "route" that describes
what a URL that you care about might look like, and then tell it what "controller" (which is a
class) should handle any request that comes in to a route that matches what you described.  Your
controller can then have multiple different methods that can handle those requests depending on the
`HttpMethod` (GET, POST, etc...) as well as the optional parameters that a user provided.

In our case, we simply want to capture the entire URL that the user sent to our proxy, strip out
the protocol and domain info, and then append that to the real Store endpoint and submit that
request.

In order to meet that requirement, there's a single "route" that has been created that looks like
this:

    {version}/{annotation}/{command}/{commandId}/{subCommand}/{subCommandId}/{subCommand2}/{subCommandId2}/{subCommand3}/{subCommandId3}/{subCommand4}/{subCommandId4}/{subCommand5}/{subCommandId5}

That will capture any API request that is up to 5 levels deep with an ID (the current v1 of the
API only goes as far as 4 levels deep with no ID).

### RootController

Any request that matches that route (which will be **every** request) will be sent to 
`RootController` which only has a single method (`RouteRequest`) and will route all
GET, DELETE, PUT, and POST requests that come to it.  It simply:

  * grabs the AbsoluteUri and QueryString (the whole Uri without the protocol or domain info)
  * decodes the body
  * checks to see if there's a special StoreBroker header indicating that the user wants the INT
    endpoint
  * grabs the user identity so that we can check to see if they are in the correct security group
    and then sends that info on to the `ProxyManager` to handle.

### ProxyManager

This is where the bulk of the work happens.  The core goals of this static class are:

  * Ensure user has permission to access the proxy server
  * Authenticate with the Submission API (and cache the AccessToken for optimized performance)
  * Send the user's original request to the real API and return the result.

The interesting things to note here:

  * We have the `EndpointInfo` class to contain all the relevan data for a single endpoint.
    This is necessary since we have both the PROD endpoint and the INT endpoint to deal with.
    This is statically initialized at the top in the `endpointInfo` dictionary.
  * AccessTokens typically have a lifetime of 1 hour.  We cache the AccessToken (along with its
    expiration time) within the relevant `EndpointInfo` object in order to cut down on
    unnecessary authentication requests.
  * The `ClientSecret` is never stored in the code.  It's accessed in encrypted form from
    the service config, and then decrypted using a private key that only exists in Azure.
    For more info on how this works, see [Client Id and Secret](#client-id-and-secret).

### AsyncLock

This is based heavily on the work of Stephen Toub, as described in his
[blog entry](https://blogs.msdn.microsoft.com/pfxteam/2012/02/12/building-async-coordination-primitives-part-6-asynclock/).

### StartUp Tasks

When the service is deployed, we need it to do a bunch of things in order to properly function.
These run as "startup tasks" that are configured within `AzureService\ServiceDefinition.csdef`.
Most of the StartUp Tasks take one or more configuration settings and make them accessible as
environment variables that exist for the duration of the Startup Task's execution.

Example:

    <Task commandLine="StartupTasks\RemoteDesktop\EnsureRemoteDesktopEnabled.cmd" executionContext="elevated" taskType="simple">
        <Environment>
            <Variable name="PathToStartupLogs">
                <RoleInstanceValue xpath="/RoleEnvironment/CurrentInstance/LocalResources/LocalResource[@name='StartupLogs']/@path" />
            </Variable>
        </Environment>
    </Task>

All of the Tasks are implemented to store their logs on the service machine in a "local resource"
called "StartupLogs".  This is defined in the `csdef` file like so:

    <LocalResources>
      <LocalStorage name="StartupLogs" cleanOnRoleRecycle="false" sizeInMB="15" />
    </LocalResources>

To see these logs, you would have to [remote](#remote-desktop) into the machine and navigate
to `c:\resources\directory\Startuplogs.<someGuid>\<taskName>`.

> In the "deployment" output window of Visual Studio, you won't generally see all (or any) of the
> Tasks running...but they are.  It's actually a little confusing, and I don't understand why you
> sometimes see them running in that output, and sometimes don't.  You can always
> [remote desktop](#remote-desktop) into the machine afterwards to see the startup logs to
> validate that they executed.

You can find the code for these tasks in the Visual Studio solution under:
`AzureService -> Roles -> RESTProxy -> bin -> StartupTasks`.  Alternatively, you can find
them in your enlistment under `AzureService\RESTProxyContent\bin\StartupTasks`.

These are the Tasks that currently run:
 
 * **LocalAdmin** - Creates a local admin account (**admin_user**) and enables it for remote desktop
   access.  The name (`LocalAdminAccountUserName`) and password (`LocalAdminAccountSecret`)
   are configurable in the service settings.  The password is encrypted using the
   [authentication certificate](#authentication-certificate).

 * **DomainJoined** - Joins the machine to your company's domain using a domain service account of
   your choosing.  It then adds that service account as an administrator and remote desktop user.
   The domain joined (`DomainJoinName`), username (`DomainJoinAccountUserName`) and password
   (`DomainJoinAccountSecret`) are configurable in the service settings.  The password is
   encrypted using the [authentication certificate](#authentication-certificate).

 * **RemoteDesktop** - Sets a registry key that enables remote desktop access on the computer, as
   this is disabled by default.

 * **TimeZone** - Chanages the machine's timezone to be PST.

 * **FixAuth** - While the `RESTProxy` WebAPI is configured to only allow Windows Authentication,
   it appears that we need to make this change at the IIS level as well.  This task will
   disable anonymous authentication and enable windows authentication.

 * **Helpers** - Not a task per se, but includes scripts that the other Tasks reference (scripts
   that help with group management and secret decryption).

----------

## Nonrepudiation

Repudiation is the **R** in [ST**R**IDE](https://msdn.microsoft.com/en-us/library/ee823878.aspx)
Threat Modeling.  **Repudiation** threats are associated with users who deny performing an action
without other parties having any way to prove otherwise -- for example, a user performs an
illegal operation in a system that lacks the ability to trace the prohibited operations.
**Nonrepudiation** refers to the ability of a system to counter repudiation threats.
For example, a user who purchases an item might have to sign for the item upon receipt.
The vendor can then use the signed receipt as evidence that the user did receive the package.

Even though we are restricting access to the REST Proxy through security groups, "bad things"
can still happen if someone starts using StoreBroker maliciously or incorrectly, or if someone's
user account is compromised and StoreBroker is used from it.  Since we are using the same
Client Id for all requets emmanating from the REST Proxy, we cannot rely on any logging that the
Store team provides.

Therefore, we need to do our own logging, that captures:
  * Username
  * Date/time
  * HTTP Method
  * AbsoluteUri & QueryString
  * Status code of the request result
  * Duration of request

We could also choose to capture the body of the request, but we are choosing to be concise, so the
above items should likely be sufficient for helping to track down who made what change in the event
that a problem in the Store has been identified.

We are leveraging Application Insights as our logging platform.  It will give us a rolling 7-day
window of all requests that come through the proxy.  The "logs" come in as "custom events" with the
event name `ProxyRequest`, and they can all be viewed in the Azure portal.  There is a _search_
box within that blade that can be used to find specific `ProxyRequest` event across any
combination of those properties.

The logging occurs in `ProxyManager.PerformRequest` within a `finally` block (so that all requests,
successful or not, will be captured).

You will need to create an `ApplicationInsights` instance in your Azure account in order to
leverage this functionality (it's Free), and then add the Application Insights Key to the
`APPINSIGHTS_INSTRUMENTATIONKEY` property in
`AzureService\ServiceConfiguration.Cloud.cscfg`.

----------

## Deployment

You can view the current deployment (both Production and Staging) in the
[Azure Portal](https://ms.portal.azure.com/).

### Production vs Staging

A **Staging** deployment is meant to be used during development to test/validate changes.

A **Production** deployment is meant to be used when changes have been validated and you want to
make them live to customers.

In practice, there is no difference between the _configuration_ of our Staging and Production
deployments (besides that categorization name), but having the differentiation is still quite
useful so that you can deploy changes that you want to test while running them in the cloud,
but without affecting live customers.

### Process

> You must have the [Azure SDK](https://azure.microsoft.com/en-us/downloads/) installed before
> you can deploy.  As of the time of this writing, the appropriate one to download
> is the one for [VS 2015](https://go.microsoft.com/fwlink/?LinkId=518003&clcid=0x409).

Deployment is very straightforward.  With the solution open, just right-click on `AzureService`
and choose **Publish**.  Choose either "Production" or "Staging" from the profile dropdown
depending on what your intention is, and then click `Publish`.

It should take roughly 5 minutes to complete.  When done, you can check the Azure portal to find
out the IP address that was created for the ILB that you should be accessing.  To find the IP,
follow the steps outlined in [A RECORD](#a-record).  You will also need to update the A RECORD
(following those steps) if you deployed to production, since the currently referenced ILB IP address
will likely have changed.

### ExpressRoute

We are leveraging [ExpressRoute](https://azure.microsoft.com/en-us/services/expressroute/) with
this service.  That enables VM's that are hosted on Azure to be able to connect to the
corporate internal network (which means that we can have seemless authentication with security
groups).

#### Classic vs ARM

ARM stands for "Azure Resource Management".  It's a new way for Azure to create and maintain
resources.  Only ARM services can access an ARM Virtual Network created by the ExpressRoute-ARM.

If you're working with a "classic" service (like what Visual Studio currently deploys), then you
need to use the "classic" ExpressRoute.

#### Configuration

The steps for creating and configuring an ExpressRoute go beyond the goal of this documentation,
as the [Azure site](https://azure.microsoft.com/en-us/documentation/services/expressroute/) has
extensive documentation already.

Once you've created your ExpressRoute, you'll need to update the following values in
`AzureService\ServiceConfiguration.Cloud.cscfg`:

    <VirtualNetworkSite name="<vnetName>" />
    <Subnet name="<subnetName>" />
    <FrontendIPConfiguration subnet="<subnetName>" type="private" />

### Remote Desktop

Remote desktop is enabled on the machines for both Staging and Production via StartupTasks.
You should probably never have to remote into the machine, but if you need to for investigations,
here's what you need to do.

First, get the IP address of the machine you want to remote into.

1. Go to the [Azure Portal](http://portal.azure.com)
2. Click on All Resources -> `storebrokerrestproxy` (the one that says: _Cloud service (classic)_)
3. In the _Overview_ blade, choose the appropriate slot (production or staging) from the dropdown
   at the top.
4. Lower in that blade, click on the "instance" of the Proxy Service that you care about (the
   current configuration deploys an Internal Load Balancer that has two instances under it).
   Grab the "Private IP Address" from the properties pane that comes up when you click on it.

Once armed with the IP address, you can remote desktop into that IP address, and log in with the
service account username and password.

### Endpoint JSON Configuration

The Proxy supports managing multiple tenants in a single Proxy instance.  Because of this,
the tenant-related configuration for the proxy is done within a JSON object that is stored as
a string property (`EndpointJsonConfig`) within the AzureService configuration
(`ServiceConfiguration.Cloud.cscfg`).

This JSON consists of an **array** of `Endpoint`s.

A single, full `Endpoint` looks like this:

    {
        "tenantId": "12324567-890a-bcde-f123-4567890abcde",
        "tenantFriendlyName": "myName",
        "type": "Prod",
        "clientId": "abcdef01-2345-6789-abcd-ef0123456789",
        "clientSecretEncrypted": "<a very long string>",
        "clientSecretCertificateThumbprint": "1234567890ABCDEF1234567890ABCDEF12345678",
        "readOnlySecurityGroupAlias": "proxyro",
        "readWriteSecurityGroupAlias": "proxyrw"
    }    

Discussing the individual values:

 * `tenantId` - The TenantId as determined when you initially [setup](SETUP.md#getting-credentials)
   StoreBroker.
 * `tenantFriendlyName` - A friendly name that StoreBroker users can use to reference this
   tenant, as opposed to needing the full `tenantId`.
 * `type`: This value should **always** be set to `Prod` (case-sensitive), unless you are adding
   an INT endpoint for the Microsoft first-party account.
 * `clientId`: The ClientId as determined when you initially [setup](SETUP.md#getting-credentials)
   StoreBroker.
 * `clientSecretEncrypted`: The ClientSecret as determined when you initially
  [setup](SETUP.md#getting-credentials) StoreBroker.  As the name implies, it's expected that you
  are [encrypting](#client-secrets) this value for security reasons.  If you don't encyrpt this
  value, then the next property (`clientSecretCertificateThumbprint`) should be left blank.
 * `clientSecretCertificateThumbprint` - The thumbprint of the certificate in Azure that was
  used for encrypting the ClientSecret into the value stored in `clientSecretEncrypted`.  If
  that value is _not_ encrypted, then this value should be left blank.
 * `readOnlySecurityGroupAlias` - The Windows Security group that is used to permit users to
  perform GET requests on this endpoint.
 * `readWriteSecurityGroupAlias` - The Windows Security group that is used to permit users to
  perform GET, POST, PUT and DELETE requests on this endpoint.

When storing the JSON in the `EndpointJsonConfig` config value, keep in mind two things:
 * It is expecting an **array** of `Endpoint` objects.  So, even if you only have a single
   `Endpoint`, it should still be wrapped within `[ ... ]` to make it an array.
 * You should "minify" the JSON to remove all line-feeds and extra spaces, and then escape all
   double-quotes (`"`) as `&quot;`.

### Maintenance items

Some of the elements of the Proxy will require occasional maintenance, like renewals, etc...

#### Service Account Password

To double-check when the password will expire, from PowerShell (replacing `<domain>` and
`<username>` with the appropriate values):

    $user = [ADSI]"WinNT://<domain>/<username>,user"
    $passwordAgeSeconds = $User.PasswordAge.psbase.Value
    $maxAgeSeconds = $User.MaxPasswordAge.psbase.Value
    $expiresInSeconds = $maxAgeSeconds - $passwordAgeSeconds
    Write-Host "Password expires on $([DateTime]::Now.AddSeconds($expiresInSeconds))"

Whenever you update the password for the account, the encrypted value of that password must _also_
be updated in the service configuration by encrypting the password with the public key of the
checked-in authentication certificate.

PowerShell:

    . .\AzureService\RESTProxyContent\bin\StartupTasks\Helpers\Encryption.ps1
    Encrypt-Asymmetric -PublicCertFilePath .\RESTProxy\certs\StoreBrokerProxyAuthentication.cer -ClearText '<password>'

Once you have that value, open `AzureService\ServiceConfiguration.Cloud.cscfg` and update
`DomainJoinAccountSecret`.

> To update the Local account password, follow the exact same steps, but change
> `LocalAdminAccountSecret` instead.

Finally, follow the simple [process](#process) to re-deploy the service.

> Remember to update the [A RECORD](#a-record) after you deploy to Production!

----------

#### Authentication Certificate

This certificate is used for encrypting / decrypting the user account passwords and the REST API
client secrets.

##### Create the Certificate

Do this from a _Visual Studio Command Prompt_ **in Administrator mode** since it has the necessary
tools in its path

    makecert -sky exchange -r -n "CN=StoreBroker Proxy Authentication" -pe -a sha256 -sr LocalMachine -ss My -e <ExpirationDate> "<PublicKeyFileName>"

  - `ExpirationDate` - The expiration date for the certificate.  Ex: "12/31/2030"
  - `PublicKeyFileName` - The file to write the public key to. It should end in **.cer**.
  Ex: "C:\certs\StoreBrokerProxyAuthentication.cer"

> If you don't do this from an **Administrator** version of that command prompt, you'll get this
> error: `Error: Save encoded certificate to store failed => 0x5 (5)`

##### Exporting the Private Key

When you run the makecert tool, it generates a public key ".cer" file in the location you specified,
and also installs a private key/certificate to your local computer that is exportable.
To export the private key:

1. Open "Manage computer certificates" (Start - >Run -> `certlm.msc`).

2. Navigate to "Certificates - Local Computer" -> "Personal" -> "Certificates".

3. Verify you see the name of the certificate you generated in the list.

4. Right-click the certificate and select "All Tasks" -> "Export".

5. In the "Certificate Export Wizard":
   a. Click "Next".

   b. Select "Yes, export the private key" and click "Next".

   c. Select "Personal Information Exchange - PKCS #12 (.PFX) and select
   "Include all certificates in the certification path if possible" and
   "Delete the private key if the export is successful".
    
   d. Click "Next"

   e. Check "Password" and enter in a password to use as the password for this certificate.
   It's recommended you use a strong and unique password.
    
   f. Click "Next"

   g. Select a destination for the private key .pfx file.
   It's recommended you place it near the .cer file and name it the same.
    
   h. Click "Next"

   f. If everything worked properly, you should get a success message.
   Click "Finish" to close the wizard and "Ok" at the prompt.

6. Since you have the public key in a .cer file and the private key in a .pfx file,
you don't need the certificate installed on your PC anymore and you can delete them.
Delete the certificate by selecting it and pressing delete.

##### Uploading the Private Key

Now you have the pfx file which has the private key embdedded in it.  We need to upload that
to Azure and then delete any local copies that we have of it.  This way, Azure will be the only
place that will be able to decode anything that we encode.

1. Navigate to the service in the [Azure Portal](http://portal.azure.com)
2. Click on Settings -> Certificates
3. **Delete** the old certificate (called "StoreBroker Proxy Authentication")
_(You may not be able to delete this until after you've deployed to Staging and Production so that
no instance of the service still references this old certificate)_.
4. Choose "Upload", select the **pfx** file that you just created and enter in the same private key
that you used during the export process (the cert file has the public key).
5. When the upload completes, you should see a **thumbrint**.  It is a 40-digit hex value that
helps Azure identify which certificate to use when decrypting.
6. Delete the local pfx file since it should only ever exist in Azure.

##### Final Steps

Replace the certificate file at `RESTProxy\certs\StoreBrokerProxyAuthentication.cer` with the
one that you just created.

Now, open `AzureService\ServiceConfiguration.Cloud.cscfg`, and you'll want to update the
following setting values:

  * `LocalAdminAccountCertThumbprint`
  * `DomainJoinAccountCertThumbprint`

You should also update the `clientSecretCertificateThumbprint` for the PROD and INT endpoints
within your [`EndpointJsonConfig`](#tenant-json-configuration).

You'll also need to update the `certificate` entry for the one named
`StoreBroker Proxy Authentication`.

It should also be noted that if you are replacing the certificate, you'll also need to update
the encrypted values of those secrets as well.  In PowerShell:

    . .\AzureService\RESTProxyContent\bin\StartupTasks\Helpers\Encryption.ps1
    Encrypt-Asymmetric -PublicCertFilePath .\RESTProxy\certs\StoreBrokerProxyAuthentication.cer -ClearText '<password>' 

> Since you probably didn't save the "client secret" values, you'll need to re-create them
> following the steps in the [section below](#client-secrets).

> Remember to update the [A RECORD](#a-record) if you deploy to Production!

----------
  
#### SSL Certificate

This isn't required, but if you want to use SSL (https://) for your proxy, you'll need to get an
SSL certificate that the machines within your company will trust (it can be an internally created
certificate if you've added your own certificate authority to all user machines).

Once downloaded, you need to first import the certificate and then export the private key for
upload to Azure.

##### Importing the Certificate

1. Download the **.cer**
2. Open "Manage computer certificates" (Start - >Run -> `certlm.msc`).
3. Navigate to "Certificates - Local Computer" -> "Personal" -> "Certificates".
4. Right click on Personal and select "All Tasks" -> "Import"
5. In the "Certificate Import Wizard":
   a. Click "Next".
   b. Click "Browse" and select the certificate that you just downloaded. Click "Open" and "Next".
   c. Select "Place certificates in the following store" and choose **Personal**.
   d. Click "Next" and then "Finish"

##### Exporting the Private Key

You're going to continue from exactly where you left off in the importing process.

1. Right-click the certificate and select "All Tasks" -> "Export".
2. In the "Certificate Export Wizard":
   a. Click "Next".

   b. Select "Yes, export the private key" and click "Next".

   c. Select "Personal Information Exchange - PKCS #12 (.PFX) and select
   "Include all certificates in the certification path if possible" and
   "Delete the private key if the export is successful".
    
   d. Click "Next"

   e. Check "Password" and enter in a password to use as the password for this certificate.
   It's recommended you use a strong and unique password.
    
   f. Click "Next"

   g. Select a destination for the private key .pfx file.
   It's recommended you place it near the .cer file and name it the same.
    
   h. Click "Next"

   f. If everything worked properly, you should get a success message.
   Click "Finish" to close the wizard and "Ok" at the prompt.

3. Since you have the public key in a .cer file and the private key in a .pfx file,
you don't need the certificate installed on your PC anymore and you can delete them.
Delete the certificate by selecting it and pressing delete.

##### Uploading the Private Key

1. Navigate to the service in the [Azure Portal](http://portal.azure.com)
2. Click on Settings -> Certificates
3. **Delete** the old certificate (called "storebrokerproxy")
_(You may not be able to delete this until after you've deployed to Staging and Production so that
no instance of the service still references this old certificate)_.
4. Choose "Upload", select the **pfx** file that you just created and enter in the same private key
that you used during the export process (the cert file has the public key).
5. When the upload completes, you should see a **thumbrint**.  It is a 40-digit hex value that
helps Azure identify which certificate to use when decrypting.
6. Delete the local pfx file since it should only ever exist in Azure.

##### Final Steps

Replace the certificate file at `RESTProxy\certs\StoreBrokerProxyHTTPS.cer` with the
one that you just created.

Now, open `AzureService\ServiceConfiguration.Cloud.cscfg`, and update the thumbrint for the
certificate named `StoreBroker Proxy HTTPS`.

    <Certificate name="StoreBroker Proxy HTTPS" thumbprint="164757AE17969A80F4CA54822C109CFA575E5419" thumbprintAlgorithm="sha1" />

> Remember to update the [A RECORD](#a-record) if you deploy to Production!

----------

#### Client Secrets

> **Frequency**: 1 or 2 years

The whole point of the proxy is to abstract away the need for the client secrets.
The client secrets can only last 1 or 2 years, and so will need to be refreshed as needed.

The steps are mostly in sync with those in [Getting Credentials](SETUP.md#getting-credentials).
If you haven't created the ClientId yet, do so now, otherwise find the one that you already
created. Once opened, you can go to the configuration, delete the existing key and choose to
create a new 2-year key.  Click **save** and then the key will appear.  Copy this value and then
run:

    . .\AzureService\RESTProxyContent\bin\StartupTasks\Helpers\Encryption.ps1
    Encrypt-Asymmetric -PublicCertFilePath .\RESTProxy\certs\StoreBrokerProxyAuthentication.cer -ClearText '<client secret>'

Do that for both the PROD and INT Clients.

Once you have the encrypted values, you'll need to update the service. Open
`AzureService\ServiceConfiguration.Cloud.cscfg` and update the corresponding setting values:

  * ClientSecretProd
  * ClientSecretInt

> Remember to update the [A RECORD](#a-record) if you deploy to Production!

----------

#### A RECORD

> **Frequency**: Whenever you deploy a new version to production

An "A RECORD" is a DNS record that points a friendly name (e.g. `storebrokerproxy`) to a specific
IP address. 

When you deploy a new version of the service, the IP address for the "internal load balancer" (ILB)
is probably going to change.  Therefore, you'll need to update the A RECORD for `storebrokerproxy`
so that it points to the right IP.

> It may take an hour for the change you make to fully propagate, which means that there may be
> downtime during this period.

1. Go to the [Azure Portal](http://portal.azure.com)
2. Click on All Resources -> `storebrokerrestproxy` (the one that says: _Cloud service (classic)_)
3. In the _Overview_ blade, make sure that the top dropdown says **Production slot** and then
   look at the "public IP address" (the one before the comma is the ILB, the one after the comma
   is a public IP that doesn't actually work, by design of ExpressRoute).
4. Follow the steps within your company for creating an A RECORD that maps the IP address from
   Step 3 to the friendly name of your choice.

----------

## Development

There are a couple things to note when doing local development:

 * You must have the [Azure SDK](https://azure.microsoft.com/en-us/downloads/) installed before
   you can do any development.  As of the time of this writing, the appropriate one to download
   is the one for [VS 2015](https://go.microsoft.com/fwlink/?LinkId=518003&clcid=0x409).

 * The code is [StyleCop](http://stylecop.codeplex.com/) clean.  Please keep it that way.
   Install StyleCop (if you don't have it installed already) and run 
   `Tools->Run StyleCop (Rescan All)` before you submit to enure that it stays clean.
 
 * When developing/debugging the service locally, you'll want to set the `RESTProxy' as the
   default project, and _not_ `AzureService`.

 * If you are deploying on your local box, it will deploy to `localhost`.  This will work fine
   unless you want to be able to have a different machine be able to access your local service.
   To work around this, you'll need to follow the steps outlined
   [here](http://johan.driessen.se/posts/Accessing-an-IIS-Express-site-from-a-remote-computer)
   (although I found that I had to manually add the firewall rule as opposed to using the
   commandline option).  If you end up getting a deployment failure from VS saying that IISExpress
   needs Admin priveleges, you may need to run the `netsh delete` command in there, then start
   debugging, and then `netsh add`.

 * If you are testing on a non-domained joined box, you'll need to do the following things
   (**but do not check them in**):

   * Click on the `RESTProxy` solution in `Solution Explorer` and _temporarily_ enable
    `Anonymous Authentication`
   * Modify `ProxyManager.TryHasPermission` to always return `true`
   * Statically add in the values for `ClientSecretProd` and `ClientSecretInt` in
    `ProxyManager.GetClientSecret`.   

 * When developing locally, you will need to tell StoreBroker to use a different endpoint for
   the proxy.  By default, this local endpoint value will be `http://localhost:1034`.  You can
   achieve that by running:

       Set-StoreBrokerAuthentication -UseProxy -ProxyEndpoint 'http://localhost:1034'

 * When running the `RESTProxy` project directly (not using the `AzureService` project),
   it won't be reading the values from your `ServiceConfiguration.[Cloud|Local].cscfg` files.  That
   means that the calls to get the `DefaultTenantId` and `EndpointJsonConfig` configuration values
   in `ConfigureProxyManager` within `WebApiConfig.cs` will come back empty.  To unblock yourself
   while debugging, you'll need to temporarily set the values from your configuration file directly
   into the code.
      * Replace any `&quot;` with `\"`.
      * Since you're not running in Azure, you won't have access to the decryption
        certificates, which means you'll need to modify the `EndpointJsonConfig` value by changing 
        `clientSecretEncrypted` to the unecrypted values, and clearing out the values for the
        `clientSecretCertificateThumbprint`s.

 * You may also need to temporarily modify `TryHasPermission` in `Endpoint.cs` to always
   return `true` if your machine isn't able to do the security group resolution.

----------

## StoreBroker Impact

The changes required to support the Proxy with StoreBroker are quite minimal.
StoreBroker already abstracts the endpoint that is accessed in order to support switching
between INT and PROD -- adding a check for Proxy in there was trivial.

`Set-StoreBrokerAuthentication` and `Clear-StoreBrokerAuthentication` were updated to
be "proxy" aware, allowing users to set (and clear) their proxy via new parameters.

Finally, in `Invoke-SBRestMethod`, we made two changes:

   * Added an additional header (`UseINT = true`) to the request if it's targeted at the Proxy
     and the user is trying to [use INT](..\README.md#using-int-vs-prod) (this way we can
     differentiate the request without touching the actual URI that we're sending). 

   * We call `Invoke-RestMethod` with the `UseDefaultCredentials` switch so that the Windows
     Identity will be sent along with the request.  We are now using that switch no matter if we
     are or are not using the Proxy because it keeps the code simpler and appears to have no
     negative effect for non-Proxy endpoints.

----------

## Using the Proxy with Other API Clients

Any Windows Store Submission API client, not just StoreBroker itself, can use the StoreBroker Proxy.

The REST API usage using the proxy is **identical** to how you use the current API, with three
specific differences:

   * The endpoint is different.  Instead of `https://manage.devcenter.microsoft.com`, the
     endpoint is `https://storebrokerproxy` (or whatever you set your [A RECORD](#a-record)
     to be. Everything else about the REST URI is identical.

   * You no longer need to get an AccessToken, nor do you need to provide an Authentication header.
     You do need to be sure to provide the default network credentials though when sending your
     request (in PowerShell, you do this with `-UseDefaultCredentials`, but there's a
     similar way to do this with other languages too)

   * If you want to use _INT_ instead of _PROD_, provide this additional header value:
     `UseINT = true`

   * If the proxy being used is multi-tenant aware, you can either pass in the tenantId in the
     header value `TenantId` or the friendly name of the tenant (as configured in the proxy)
     with the header value `TenantName`.

----------

## References

 * [How Routing works with ASP.net WebApi](http://www.asp.net/web-api/overview/web-api-routing-and-actions/routing-in-aspnet-web-api)
 * [Enable local IIS Express server to be accessed remotely](http://johan.driessen.se/posts/Accessing-an-IIS-Express-site-from-a-remote-computer)