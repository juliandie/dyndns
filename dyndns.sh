#!/bin/bash

BASENAME="$(basename "$0")"

if [ -z "$(which dig)" ]; then
    echo "Please install bind9-dnsutils (or a package that provides dig)"
    exit 1
fi

# Init variables
DYNDNS_NS="1.1.1.1"
#DYNDNS_CFG=""
DYNDNS_URL=""
DYNDNS_HOST=""
DYNDNS_USER=""
DYNDNS_PASS=""
DYNDNS_DRYRUN="false"
DYNDNS_IGNORE_IPV4="false"
DYNDNS_IGNORE_IPV6="false"

function show_help() {
    echo "usage: ${BASENAME} [-v] -u <user> -i <password> -h <host1> -h <host2> -d <url>"
    echo " -u --user <user>             The dyndns-user"
    echo " -i --key --password <pass>   The auth for a dyndns update (password/token)"
    echo " -l --host <host>             The dyndns-host address (e.g. mydomain.com)"
    echo " -d --url <url>               The dyndns update URL"
    echo " -n --ns <ns>                 Use nameserver for dyndns reference (default: 1.1.1.1)"
    echo " -c --config <cfg>            Read user, key, host, url from a configuration-file"
    echo " --dry-run                    Don't actually execute the dyndns-update"
    echo ""
    echo "Below tags will be replaced with related data in the dyndns update URL."
    echo "<user>, <pass>, <host>, <ipv4>, <ipv6>"
    echo "example url: https://ddnss.de/udp.php?key=<pass>&host=<host>&ip=<ipv4>"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        "-d"|"--url") DYNDNS_URL="$2"; shift;;
        "-u"|"--user") DYNDNS_USER="$2"; shift;;
        "-i"|"--key"|"--password") shift;;
        "-l"|"--host") DYNDNS_HOST="$2"; shift;;
        "-n"|"--ns") DYNDNS_NS="$2"; shift;;
        "-c"|"--config") DYNDNS_CFG="$2"; shift;;
        "--dry-run") DYNDNS_DRYRUN="true";;
        "-h"|"--help") show_help; exit 0;;
        *)
            echo "Invalid argument $1"
            show_help
            exit 1
    esac
    shift # past arg
done

if [ -n "${DYNDNS_CFG}" ]; then
    # shellcheck source=./example.ddnss.de
    source "${DYNDNS_CFG}"
fi

if [ -z "${DYNDNS_URL}" ] || [ -z "${DYNDNS_HOST}" ]; then
    echo "$(date) ERROR: Invalid url or host"
    exit 1
fi

function ip_test() {
    TEST_IPV="$1"
    case "$TEST_IPV" in
        "-4")
            TEST_TXT="4"
            TEST_REC="A"
            ;;
        "-6")
            TEST_TXT="6"
            TEST_REC="AAAA"
            ;;
        *)
            return 0
            ;;
    esac

    # Get our public IP
    WAN_IP="$(curl "${TEST_IPV}" ifconfig.co 2> /dev/null)"
    if [ -z "${WAN_IP}" ]; then
        echo "$(date) ERROR: Couldn't get WAN-IPv${TEST_TXT}"
        return 0
    fi

    # Get the currently registered dyn-dns IP
    DNS_IP="$(dig +short -t "${TEST_REC}" "${DYNDNS_HOST}" @"${DYNDNS_NS}" 2> /dev/null)"
    if [ -z "${DNS_IP}" ]; then 
        DNS_IP="none" 
    fi

    # If there's none, expect we shouldn update it
    if [ "${DNS_IP}" == "none" ]; then
        echo "$(date) DEBUG: No valid Dyn-DNS IPv${TEST_TXT}"
        return 0
    fi

    # Don't bother the dyn-dns API when there's no change
    if [ "${WAN_IP}" == "${DNS_IP}" ]; then
        echo "$(date) DEBUG: IPv${TEST_TXT} didn't change (old: ${WAN_IP})"
        # Update URL just in case the other IPvX needs to update
        DYNDNS_URL="$(echo "${DYNDNS_URL}" | sed -E "s/<ipv${TEST_TXT}>/""${WAN_IP}"'/g')"
        return 0
    else
        echo "$(date) INFO: IPv${TEST_TXT} changed (${DNS_IP} > ${WAN_IP})"
        DYNDNS_URL="$(echo "${DYNDNS_URL}" | sed -E "s/<ipv${TEST_TXT}>/""${WAN_IP}"'/g')"
        return 1
    fi
}

if [ "${DYNDNS_IGNORE_IPV4}" == "false" ]; then
    ip_test -4
    DYNDNS_UP4="$?"
fi

if [ "${DYNDNS_IGNORE_IPV6}" == "false" ]; then
    ip_test -6
    DYNDNS_UP6="$?"
fi

DYNDNS_URL="$(echo "${DYNDNS_URL}" | sed -E 's/<user>/'"${DYNDNS_USER}"'/g')"
DYNDNS_URL="$(echo "${DYNDNS_URL}" | sed -E 's/<pass>/'"${DYNDNS_PASS}"'/g')"
DYNDNS_URL="$(echo "${DYNDNS_URL}" | sed -E 's/<host>/'"${DYNDNS_HOST}"'/g')"

if [ "${DYNDNS_DRYRUN}" == "true" ]; then
    echo "${DYNDNS_URL}"
else
    if [ "${DYNDNS_UP4}" == "1" ] || [ "${DYNDNS_UP6}" == "1" ]; then
        curl -s "${DYNDNS_URL}"
    fi
fi

exit 0

