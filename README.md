# init-machine.sh

This is a simple script to initialize an environment for doing basic penetration
testing on Hack the Box style machines. It can even use the `htb-cli` python
package to retrieve hack the box machines via their name, and setup a consistent
environment for testing.

## Usage

```
Usage: ./init-machine.sh [OPTION]... (machine_regex|machine_id|ip)

Initialize a new Hack the Box machine directory structure and perform initial
scans.

Options:
        -h               display this help message
        -t               perform TCP scans (default)
        -u               perform UDP scans
        -b               search for the given machine on hack the box
        -n               machine name (used for /etc/hosts and directory)
        -k               hack the box api key location (default: ./.htb-key)
        -i               interface for masscan (default: tun0)

Parameters:
        machine_regex    `grep -iE` compatible regex for machine name
        machine_id       numeric machine identifier
        ip               IP address of non-hack-the-box machine
```

## Features

- Adds given hostname/IP pair to /etc/hosts
- Creates a consistent directory structure for testing
- Performs initial scan of all ports using `masscan` (optionally including UDP)
- Performs more in-depth scan of open ports using `nmap`
- Ability to utilize the `htb-cli` module in python. You can specify a machine
  name (by regex), and the script will query the HTB API to find the IP address
  and appropriate hostname.

## Hack the Box Integration

In order to utilize the Hack the Box integration, you'll need to install the
`htb-cli` module via `pip`:

```
$ pip install htb-cli
```

This will install a script called `hackthebox.py` which `init-machine` uses to
enumerate available machine names and translate them to IP addresses. It
requires your private API key to function, so you can grab that from [Hack the
Box](https://www.hackthebox.eu) by going to your profile settings, and looking
on the right side of the page under `API Key`. You'll need to place the key in a
file somewhere on your machine for `init-machine` to find. By default,
`init-machine` will look for `./.htb-key`. I suggest applying appropriate
permissions to the file, as this key allows other people to effectively login to
hack the box without your password.

You can also manually specify the API key path with the `-k` parameter:

```
$ ./init-machine.sh -b -k ~/.htb-key Sniper
```
