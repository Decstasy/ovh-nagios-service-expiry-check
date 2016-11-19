# Nagios Service Expiry Check for OVH, SoYouStart and Kimsufi 

## Content:
1. [Description](#description)
  1. [Prologue](#prologue)
  2. [What it's designed for](#what-its-designed-for)
  3. [The result in Nagios](#the-results-in-nagios)
2. [Installation](#installation)
  1. [Requirements](#requirements)
  2. [Generate API keys](#generate-api-keys)
  3. [Configure Nagios](#configure-nagios---general-notes)
	* [General notes](#configure-nagios---general-notes)
    * [Domains](#configure-nagios---domains)
    * [Dedicated servers](#configure-nagios---dedicated-servers)
3. [License](#license)

## Description
### Prologue
Please don't hesitate to contact me via [e-mail](mailto:request@decstasy.de) if you have suggestions, ideas, feature requests or bugs.

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
### Requirements
To run this properly you should have Bash version 4.x and the following additional commands must be available:
* curl (to communicate with the API)
* sha1sum (for API signature)

### Generate API keys
In order to use this script you have to generate 3 keys for the API which are the:
* Application key
* Application secret
* Consumer key (token)

Since I implemented a guide to generate theese keys it's pretty simple. Just follow this steps...
* Place the script in your "/usr/local/nagios/libexec/" or "/usr/lib64/nagios/plugins/" directory
* Add execution bit to file (chmod +x check_ovh_service_expiry.sh)
* Execute the script with -g parameter and follow instructions

### Configure Nagios - General notes
You have to think about YOUR best solution to implement this monitoring. I'm now talking about my case which suits best for me. I have domains via OVH and servers via SoYouStart which means I have to use different keys. This means I cannot set default keys in the script or command definition - they must be dynamically controled by nagios. As I don't want things to get messy, the best solution is to work with custom object variables. The following configuration is able to use different keys per CI.

### Configure nagios - Domains
I suggest to configure a domain as a host and perform the expiry check as host check. In this example configuring a domain from ovh. Please, alter the following definitions for your needs... You can get the possible parameters and values by executing the script with -h parameter.

First you will need a new command:
```
define command {
        command_name                    check_ovh_service_expiry_domain
        command_line                    $USER1$/check_ovh_service_expiry.sh -P $_HOSTPROVIDER_NAME$ -t domain -k $_HOSTAPP_KEY$ -s $_HOSTAPP_SECRET$ -c $_HOSTCUST_KEY$ -p $HOSTNAME$ -W $ARG1$ -C $ARG2$
        register                        1
}
```

Define a new host template to make things easier:
```
define host {
        name                            generic-domain
        hostgroups                      Domains
        check_command                   check_ovh_service_expiry_domain!14!7
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

In order to keep your overview organized, add the matching hostgroup:
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
        host_name*                      decstasy.de
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
**It's important to set host_name to your-domain.com (see command definition).*

### Configure nagios - Dedicated servers
I suggest you to check the expiry as a nagios service and store the keys in the host definition - in this example configuration a dedicated server from SoYouStart. Please, alter the following definitions for your needs... You can get the possible parameters and values by executing the script with -h parameter.

First you will need a new command:
```
define command {
        command_name                    check_ovh_service_expiry_server
        command_line                    $USER1$/check_ovh_service_expiry.sh -P $_HOSTPROVIDER_NAME$ -t server -k $_HOSTAPP_KEY$ -s $_HOSTAPP_SECRET$ -c $_HOSTCUST_KEY$ -p $_HOSTSERVER_NAME$ -W $ARG1$ -C $ARG2$
        register                        1
}
```

Define a new service:
```
define service {
        host_name                       host.decstasy.de
        service_description             Server expiry
        servicegroups                   Contract
        use                             local-service
        check_command                   check_ovh_service_expiry_server!7!3
        max_check_attempts              1
        check_interval                  60
        retry_interval                  1
        check_period                    24x7
        process_perf_data               0
        register                        1
}
```

Define the corresponding servcie group for a better overview:
```
define servicegroup {
        servicegroup_name               Contract
        alias                           Contract affecting stuff
        register                        1
}
```

And now add the custom variables used by the service to your host:
```
define host {
        host_name                       host.decstasy.de
        [...]
        _APP_KEY                        kdOCIoHXmNnb4FII
        _APP_SECRET                     Wn5ZJnhLISvRK6gD2MDygwAp0WFxelTe
        _CUST_KEY                       x6u7Dl1oukE1kOX3FxeVPj2dWUyw6V0C
        _PROVIDER_NAME                  sys
        _SERVER_NAME*                   ns304258.ip-94-24-218.eu
        register                        1
}
```
**There is also the custom variable SERVER_NAME as the provider's server name may be different from your hostname - you can get it in your webinterface.*

## License
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.

This program is distributed hoping that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, see http://www.gnu.org/licenses/
