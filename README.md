# Nagios Service Expiry Check for OVH, SoYouStart and Kimsufi 

## Content:
1. [Description](#description)
  1. [What it's designed for](#what-its-designed-for)
  2. [The result in Nagios](#the-results-in-nagios)
2. [Installation](#installation)
  1. [Generate API keys](#generate-api-keys)
  2. [Configure Nagios](#configure-nagios)
	* General notes
    * Domains
    * Dedicated servers

## Description
### What it's designed for
This script is designed to check the expiry date of dedicated servers and domains directly via API. It is especially designed to return the result in a typical nagios format.

You can use it for servers and domains from:
* OVH
* SoYouStart
* Kimsufi

### The results in Nagios
The domain check will look like this:
```
Ok: decstasy.de will expire in 210 days on 2017-03-15.
```
And servers very similar:
```
Ok: ns304258.ip-94-23-210.eu will expire in 19 days on 2016-09-05.
```

## Installation
### Generate API keys
In order to use this script you have to generate 3 keys for the API which are the:
* Application key
* Application secret
* Consumer key (token)

Since we implemented a guide to generate theese keys it's pretty simple. Just follow this steps...
* Place the script in your /usr/local/nagios/libexec/ or /usr/lib64/nagios/plugins/
* Add execution bit to file (chmod +x check_ovh_service_expiry.sh)
* Execute the script with -g parameter and follow instructions

### Configure Nagios - General notes
You have to think about YOUR best solution to implement this monitoring. I'm now talking about my case which suits best for me. I have domains via OVH and servers via SoYouStart which means I have to use different keys. This means I cannot set default keys in the script or command definition - they must be dynamically controled by nagios. As I dont want, that things get messy, the best solution is to work with custom object variables. The following configuration is able to use different keys per CI.

### Configure nagios - Domains
I suggest to configure a domain as a host and perform the expiry check as host check. In this example configuration a domain from ovh. Please alter the following definitions for your needs... 

First you will need a new command:
```
define command {
        command_name                    check_provider_expiry_domain
        command_line                    $USER1$/check_provider_expiry.sh -P $_HOSTPROVIDER_NAME$ -t domain -k $_HOSTAPP_KEY$ -s $_HOSTAPP_SECRET$ -c $_HOSTCUST_KEY$ -p $HOSTNAME$ -W $ARG1$ -C $ARG2$
        register                        1
}
```

Define a new host template to make things easier:
```
define host {
        name                            generic-domain
        hostgroups                      Domains
        check_command                   check_provider_expiry_domain!14!7
        initial_state                   u
        max_check_attempts              1
        check_interval                  60
        retry_interval                  5
        check_period                    24x7
        event_handler                   notify-host-by-email
        event_handler_enabled           1
        flap_detection_enabled          1
        process_perf_data               1
        retain_status_information       1
        retain_nonstatus_information    1
        notification_interval           0
        notification_period             24x7
        first_notification_delay        20
        notification_options            d,r,f,s
        notifications_enabled           1
        register                        0
}
```

To establish order in your overview, add the matching hostgroup:
```
define hostgroup {
        hostgroup_name                  Domains
        alias                           Domains
        register                        1
}
```

And now the final configuration... Your domain as host:
```
define host {
        host_name                       decstasy.de
        alias                           Domain decstasy.de
        address                         decstasy.de
        use                             generic-domain
        contacts                        admin
        _APP_KEY                        NyFnplDjNMrbZhxC
        _APP_SECRET                     FurNRpInYpUkkwp89heVmjXu9Qpbta85
        _CUST_KEY                       MtxEQIjUsfMutoNwhLylRpITxjdT7vrp
        _PROVIDER_NAME                  ovh
        register                        1
}
```
**It's important to set host_name to your-domain.com (see command definition)*

### Configure nagios - Dedicated servers
**Coming soon**
