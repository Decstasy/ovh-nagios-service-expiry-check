#!/bin/bash

#  ┌────────────────────────────────────────────────────────────────────────────╖
#  │ Nagios script to check Domain and Server expiry date from ovh,             ║
#  │ SoYouStart and Kimsufi.                                                    ║
#  │ Copyright (C) 2016 Dennis Ullrich                                          ║
#  │ E-Mail: request@decstasy.de                                                ║
#  ├────────────────────────────────────────────────────────────────────────────╢
#  │ This program is free software; you can redistribute it and/or modify       ║
#  │ it under the terms of the GNU General Public License as published by       ║
#  │ the Free Software Foundation; either version 3 of the License,             ║
#  │ or (at your option) any later version.                                     ║
#  │                                                                            ║
#  │ This program is distributed in the hope that it will be useful,            ║
#  │ but WITHOUT ANY WARRANTY; without even the implied warranty of             ║
#  │ MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU           ║
#  │ General Public License for more details.                                   ║
#  │                                                                            ║
#  │ You should have received a copy of the GNU General Public License          ║
#  │ along with this program; if not, see <http://www.gnu.org/licenses/>.       ║
#  ├────────────────────────────────────────────────────────────────────────────╢
#  │ Changelog:                                                                 ║
#  │ 2016-03-29 Version 0.1b                                                    ║
#  │    + First release                                                         ║
#  │ 2016-08-15 Version 0.1                                                     ║
#  │    + Added function to generate keys (-g) and altered help                 ║
#  │ 2017-05-30 Version 0.2                                                     ║
#  │    + Changed get_exp_date to use a for loop with 3 retries                 ║
#  │      (to handle API query problems)                                        ║
#  ╘════════════════════════════════════════════════════════════════════════════╝

#----------------------------------------------#
##### --------------- FUNC --------------- #####
#----------------------------------------------#

function usage {
    cat << EOF
Usage: ${0##*/} [-hd] [-W warn in day(s)] [-C critical in day(s)] [-P provider]
[-t Type (domain/server)] [-k Application Key] [-s Application Secret] [-c Consumer Key] [-p product]

Check expiry date of Server's and Domain's from OVH (ovh), SoYouStart (sys) and Kimsufi (ksf).

-h                      Display this help and exit
-d                      Debug mode (be aware - your terminal will be spammed)
-g                      Generate API keys - just follow instructions on terminal.
-W [Days]               Warn before product will expire in day(s) - optional - default 5
-C [Days]               Raise critical notification in day(s) before product will expire - optional - default 2
-P [Provider]           Allowed values: ovh, sys, ksf
-t [Type]               Allowed values: domain, server
-k [Application Key]    The key e.g.: kdODIcFCmNnb8FII
-s [Application Secret] The secret e.g.: Wn5ZJmhLISvRT6gV7GDygwAp0WFzbkLe
-c [Consumer Key]       The key e.g.: x6u9Bs3oukK1kOX3FxkVPj2dWByw6U0C
-p [product]            Your product name e.g.: ns355884.ip-188-165-243.eu

-----------------------------------------------------------------------------------------------------------------

Execute the Script with -g parameter to generate the keys. You will be guided through the whole process.

If it does not work for any reason... You can get the API keys here:
OVH: https://eu.api.ovh.com/createApp/
SYS: https://eu.api.soyoustart.com/createApp/
KSF: https://eu.api.kimsufi.com/createApp/

You have to generate the consumer key after you generated the application key and secret.
You should read this: https://api.ovh.com/g934.first_step_with_api#creating_identifiers_requesting_an_authentication_token_from_ovh

Allow access to:
/dedicated/server/*
/domain/*

If you get with enabled debug mode output like this:
{"errorCode":"INVALID_CREDENTIAL","httpCode":"403 Forbidden","message":"This credential is not valid"}
You have done something wrong with your key request.

EOF
    exit 3
}

function check_progs {
        rc=0
        for program in curl sha1sum; do
                hash $program >/dev/null 2>&1
                if [ $? -ne 0 ]; then
                        echo "No $program installed."
                        rc=1
                fi
        done
        if [ $rc -ge 1 ]; then
                exit $rc
        fi

        true
}

function sys_query {
        if [ $# -ne 2 -o $# -eq 3 ]; then
                echo "Usage: sys_query [Method] [Url] [Body(optional)]"
                false
        fi

        # Timestamp
        ts="$(date -u +'%s')"
        #ts="$(curl -s $api/auth/time)"

        method="$1"
        query="$api$2"
        if [ -z $3 ]; then
                body=""
        else
                body="$3"
        fi

        signature="$as+$ck+$method+$query+$body+$ts"
        signature="$(sha1sum <(echo -n "$signature") | awk '{print $1}')"

        result="$(curl -s -H "X-Ovh-Application:$ak"    \
        -H "X-Ovh-Timestamp:$ts"                        \
        -H "X-Ovh-Signature:\$1\$$signature"            \
        -H "X-Ovh-Consumer:$ck"                         \
        $query)"

        echo "$result"
}

function get_exp_date {
    # Loop with 3 tries since OVH has sometimes API problems
    for ((i = 0 ; i <= 2 ; i++)); do
        # Query provider
        ExpirationDate="$(sys_query 'GET' "${pre_query}${serviceName}/serviceInfos")"
        # Grep date from returned information
        ExpirationDate="$(echo "$ExpirationDate" | grep -oP '("expiration":")\K\d{4}-\d{2}-\d{2}')"
        if [ $? = 0 ]; then
            echo "$ExpirationDate"
            rc=0
            break
        else
            rc=3
        fi
        [[ $i -lt 2 ]] && sleep 5
    done
    [[ $rc -eq 3 ]] && >&2 echo "Could not get \$ExpirationDate in function get_exp_date. sys_query output: $(sys_query 'GET' "${pre_query}${serviceName}/serviceInfos")"
    return $rc
}

function generate_key {
   echo -en "You have to generate 3 keys via the API to use this script in the first place.
You will be guided through this - its really simple.
If you want to know what's going on, you may read this: https://api.ovh.com/g934.first_step_with_api

Choose your Provider:
1 OVH
2 SoYouStart
3 Kimsufi
Answer [1-3]: "
   read answer
   regex='^[1-3]$'
   if ! [[ $answer =~ $regex ]] ; then
        >&2 echo "Error: Not a valid number!"
        exit 1
   fi
   case $answer in
        1) api="https://eu.api.ovh.com"
        ;;
        2) api="https://eu.api.soyoustart.com"
        ;;
        3) api="https://eu.api.kimsufi.com"
        ;;
   esac

   echo -en "\n- Open your browser: $api/createApp/
- Enter your credentials
- Enter application name e.g. NagiosExpiryCheck
- Enter application description e.g. checks service expiry date
You will get the application key and an application secret key.
You should store both of them in a safe place - you will need it later.
Ready for the next step [y|n]? "
   read answer
   answer=${answer,,} # convert all to lower case
   regex='^(yes|ye|y)$'
   if ! [[ $answer =~ $regex ]]; then
        >&2 echo "Really? o.O"
        exit 1
   fi

   echo -en "\nPlease enter your keys in order to query the API to get your consumer key.
\e[1m!!! Pay attention that there are no whitespaces in your answer !!!\e[0m
Enter application key: "
   read ak
   echo -en "Enter application secret: "
   read as
   regex='^[a-zA-Z0-9]+$'
   for answer in $ak $as; do
        if ! [[ $answer =~ $regex ]] ; then
           >&2 echo "Error: Invalid input. Only uppercase, lowercase character from a-z and numbers from 0-9 allowed!"
           exit 1
        fi
   done

   echo -en "\nQuerying API... "
   response="$(curl -XPOST -H"X-Ovh-Application: $ak" -H "Content-type: application/json" $api/1.0/auth/credential  -d '{
        "accessRules": [
                {
                  "method": "GET",
                  "path": "/dedicated/server/*"
                },
                {
                  "method": "GET",
                  "path": "/domain/*"
                }
        ]
   }' 2>/dev/null | sed 's/,/\n/g' | grep -oP '(https:\/\/.*Token=[\w\d]*)|((?<=consumerKey":")[\w\d]*)')"
   if [ "$(echo "$response" | wc -l)" = "2" ]; then
        echo "OK"
   else
        >&2 echo "FAILED - Did not get the expected response."
        >&2 echo "Please check your application key and the connection to the API $api. Perhaps run this script with -d parameter?"
        exit 1
   fi
   ValidationURL=$(echo "$response" | head -n 1)
   ck=$(echo "$response" | tail -1)

   echo -e "\nOpen the following URL in your browser to validate your consumer key: $ValidationURL
Enter your credentials again and choose \"Validity: Unlimited\"

After that... You should get the response \"Your token is now valid, you can use it in your application\" on top of the page.

Here are your 3 keys to finally use this script:
application key: $ak
application secret: $as
consumer key: $ck"

   exit 0
}

#----------------------------------------------#
##### --------------- VARS --------------- #####
#----------------------------------------------#

# Defaults...
warn=5
crit=2
api=
pre_query=
# Application Key
ak=
# Application Secret
as=
# Consumer Key
ck=
serviceName=

# Parse options
while getopts “:hdgW:C:P:t:k:s:c:p:” OPTION; do
    case $OPTION in
        d)          # Debug
                    set -x
            ;;
        h)          usage
            ;;
        g)          check_progs
                    generate_key
            ;;
        W)          warn=$OPTARG
            ;;
        C)          crit=$OPTARG
            ;;
        P)          case $OPTARG in
                        'ovh')  api="https://eu.api.ovh.com/1.0"
                            ;;
                        'sys')  api="https://eu.api.soyoustart.com/1.0"
                            ;;
                        'ksf')  api="https://eu.api.kimsufi.com/1.0"
                            ;;
                        *)
                             >&2 echo "Unknown argument $OPTARG in Option $OPTION. Execute script with -h option to get help."; exit 3
                            ;;
                    esac
            ;;
        t)          case $OPTARG in
                        'domain')   pre_query="/domain/"
                            ;;
                        'server')   pre_query="/dedicated/server/"
                            ;;
                        *)           >&2 echo "Unknown argument $OPTARG in Option $OPTION. Execute script with -h option to get help."; exit 3
                            ;;
                    esac
            ;;
        k)          ak="$OPTARG"
            ;;
        s)          as="$OPTARG"
            ;;
        c)          ck="$OPTARG"
            ;;
        p)          serviceName="$OPTARG"
            ;;
        '?')         >&2 echo "Unknown argument $OPTARG in Option $OPTION. Execute script with -h option to get help."; exit 3
            ;;
    esac
done
shift "$((OPTIND-1))" # remove the options and optional --

# Check that we have everything we need
if [[ -z $serviceName ]] || [[ -z $ak ]] || [[ -z $as ]] || [[ -z $ck ]] || [[ -z $api ]] || [[ -z $pre_query ]]; then
         >&2 echo 'UNKNOWN: Not all required arguments are given. Execute script with -h option to get help.'
         exit 3
fi

#----------------------------------------------#
##### --------------- MAIN --------------- #####
#----------------------------------------------#

check_progs

ExpirationDate="$(get_exp_date)" || exit 3
# Calculate... The target date - current time in seconds and break down to days
DaysUntilExpiration=$(( ( $(date -ud $ExpirationDate +'%s') - $(date -u +'%s') )/60/60/24 ))

if [ $DaysUntilExpiration -gt $warn ];then
    echo "Ok: $serviceName will expire in $DaysUntilExpiration days on $ExpirationDate."
    exit 0
elif [ $DaysUntilExpiration -le $crit -o $DaysUntilExpiration -lt 0 ];then
    echo "Critical: $serviceName will expire in $DaysUntilExpiration day(s) on $ExpirationDate!"
    exit 2
elif [ $DaysUntilExpiration -le $warn ]; then
    echo "Warning: $serviceName will expire in $DaysUntilExpiration days on $ExpirationDate!"
    exit 1
else
    echo "Unknown: Please debug me. Maybe the wrong product name \"$serviceName\"? "
    exit 3
fi
