# dyndns updater

This script looks up the ipv4 and ipv6 address of a defined domain name.
As the ip address differs from the currently used ip address, it tries to
update the ip address, using the dyn dns api.


# configuration parameters

A configuration file can define following variables if required.

## DYNDNS_NS

A custom nameserver that is used to verify the current dyn-dns address

## DYNDNS_URL

The update url that is called by a GET request.
From inside the script, values for parameters <ipv4> and <ipv6> will be provided.

## DYNDNS_HOST

The hostname that's gonna be used to find the current dyn-dns ip address.
In the DYNDNS_URL, the <host> parameter will be replaced with this value. 

## DYNDNS_USER

The username that might be required in the update url.
In the DYNDNS_URL, the <user> parameter will be replaced with this value.

## DYNDNS_PASS

The password or key that's required in the update url.
In the DYNDNS_URL, the <pass> parameter will be replaced with this value.


# crontab example

Test every 10 minutes, if the ip has been changed
```
*/10 * * * * /usr/bin/dyndns.sh -c /etc/dyndns.d/domainname
```

