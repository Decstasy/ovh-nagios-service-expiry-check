#!/bin/bash

#  ┌────────────────────────────────────────────────────────────────────────────╖
#  │ Nagios script to check Domain and Server exexpiry date from ovh,           ║
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
-W [Days]               Warn before product will expire in day(s) - optional - default 5
-C [Days]               Raise critical notification in day(s) before product will expire - optional - default 2
-P [Provider]           Allowed values: ovh, sys, ksf
-t [Type]               Allowed values: domain, server
-k [Application Key]    The key e.g.: kdODIcFCmNnb8FII
-s [Application Secret] The secret e.g.: Wn5ZJmhLISvRT6gV7GDygwAp0WFzbkLe
-c [Consumer Key]       The key e.g.: x6u9Bs3oukK1kOX3FxkVPj2dWByw6U0C
-p [product]            Your product name e.g.: ns355884.ip-188-165-243.eu

-----------------------------------------------------------------------------------------------------------------

You can get the API keys here:
OVH: https://eu.api.ovh.com/createApp/
SYS: https://eu.api.soyoustart.com/createApp/
KSF: https://eu.api.kimsufi.com/createApp/

You have to validate the token after you generated the consumerKey.
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
        for program in curl sha1sum awk grep; do
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
    # Query provider
    ExpirationDate="$(sys_query 'GET' "${pre_query}${serviceName}/serviceInfos")"
    # Grep date from returned information
    ExpirationDate="$(echo "$ExpirationDate" | grep -oP '("expiration":")\K\d{4}-\d{2}-\d{2}')"
    if [ $? = 0 ]; then
        echo "$ExpirationDate"
        true
    else
        >&2 echo 'Could not get $ExpirationDate in function get_exp_date. Please debug me.'
        >&2 echo "sys_query ... output: $(sys_query 'GET' "${pre_query}${serviceName}/serviceInfos")"
        exit 3
    fi
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
while getopts “:hdW:C:P:t:k:s:c:p:” OPTION; do
    case $OPTION in
        d)          # Debug
                    set -x
            ;;
        h)          usage
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
