#!/bin/bash

BASENAME="$(basename "$0")"

# Init variables
DDNS_NS="1.1.1.1"
#DDNS_CFG=""
DDNS_URL=""
DDNS_HOST=""
DDNS_USER=""
DDNS_PASS=""
DDNS_DRYRUN="false"

function show_help() {
    echo "usage: ${BASENAME} [-v] -u <user> -i <password> -h <host1> -h <host2> -d <url>"
    echo " -u --user <user>             The ddns-user"
    echo " -i --key --password <pass>   The auth for a ddns update (password/token)"
    echo " -l --host <host>             The ddns-host address (e.g. mydomain.com)"
    echo " -d --url <url>               The ddns update URL"
    echo " -n --ns <ns>                 Use nameserver for ddns reference (default: 1.1.1.1)"
    echo " -c --config <cfg>            Read user, key, host, url from a configuration-file"
    echo " --dry-run                    Don't actually execute the ddns-update"
    echo ""
    echo "Below tags will be replaced with related data in the ddns update URL."
    echo "<user>, <pass>, <host>, <ipv4>, <ipv6>"
    echo "example url: https://ddnss.de/udp.php?key=<pass>&host=<host>&ip=<ipv4>"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        "-d"|"--url") DDNS_URL="$2"; shift;;
        "-u"|"--user") DDNS_USER="$2"; shift;;
        "-i"|"--key"|"--password") shift;;
        "-l"|"--host") DDNS_HOST="$2"; shift;;
        "-n"|"--ns") DDNS_NS="$2"; shift;;
        "-c"|"--config") DDNS_CFG="$2"; shift;;
        "--dry-run") DDNS_DRYRUN="true";;
        "-h"|"--help") show_help; exit 0;;
        *)
            echo "Invalid argument $1"
            show_help
            exit 1
    esac
    shift # past arg
done

if [ -n "${DDNS_CFG}" ]; then
    # shellcheck source=./ddnsu.example.ddnss.de
    source "${DDNS_CFG}"
fi

if [ -z "${DDNS_URL}" ] || [ -z "${DDNS_HOST}" ]; then
    echo "$(date) ERROR: Invalid host"
    exit 1
fi

case "${DDNS_URL}" in
    *"<ipv4>"*)
    WAN_IP4="$(curl -4 ifconfig.co 2> /dev/null)"
    if [ -z "${WAN_IP4}" ]; then
        echo "$(date) ERROR: Couldn't get WAN-IPv4"
        exit 1
    fi
    DNS_IP4="$(dig +short -t A "${DDNS_HOST}" @"${DDNS_NS}" 2> /dev/null)"
    if [ -z "${DNS_IP4}" ]; then 
        DNS_IP4="none" 
    fi
    if [ "${WAN_IP4}" == "${DNS_IP4}" ]; then
        echo "$(date) INFO: IPv4 didn't change (${WAN_IP4})"
        exit 0
    else
        echo "$(date) INFO: IPv4 changed (${DNS_IP4} > ${WAN_IP4})"
        DDNS_URL="$(echo "${DDNS_URL}" | sed -E 's/<ipv4>/'"${WAN_IP4}"'/g')"
    fi
    ;;
esac

case "${DDNS_URL}" in
    *"<ipv6>"*)
        WAN_IP6="$(curl -6 ifconfig.co 2> /dev/null)"
        if [ -z "${WAN_IP6}" ]; then
            echo "$(date) ERROR: Couldn't get WAN-IPv6"
            exit 1
        fi
        DNS_IP6="$(dig +short -t AAAA "${DDNS_HOST}" @"${DDNS_NS}" 2> /dev/null)"
        if [ -z "${DNS_IP6}" ]; then
            DNS_IP6="none" 
        fi
        if [ "${WAN_IP6}" == "${DNS_IP6}" ]; then
            echo "$(date) INFO: IPv6 didn't change (${WAN_IP6})"
            exit 0
        else
            echo "$(date) INFO: IPv6 changed (${DNS_IP6} > ${WAN_IP6})"
            DDNS_URL="$(echo "${DDNS_URL}" | sed -E 's/<ipv6>/'"${WAN_IP6}"'/g')"
        fi
        ;;
esac

DDNS_URL="$(echo "${DDNS_URL}" | sed -E 's/<user>/'"${DDNS_USER}"'/g')"
DDNS_URL="$(echo "${DDNS_URL}" | sed -E 's/<pass>/'"${DDNS_PASS}"'/g')"
DDNS_URL="$(echo "${DDNS_URL}" | sed -E 's/<host>/'"${DDNS_HOST}"'/g')"

if [ "${DDNS_DRYRUN}" == "true" ]; then
    STATUS="${DDNS_URL}"
else
    STATUS=$(curl -s "${DDNS_URL}")
fi
echo "${STATUS}"

exit 0

