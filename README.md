# init-machine.sh

This is a simple script to initialize an environment for doing basic penetration
testing on Hack the Box style machines. It can even use the `htb-cli` python
package to retrieve hack the box machines via their name, and setup a consistent
environment for testing.

## Features

- Adds given hostname/IP pair to /etc/hosts
- Creates a consistent directory structure for testing
- Performs initial scan of all ports using `masscan` (optionally including UDP)
- Performs more in-depth scan of open ports using `nmap`
- Ability to utilize the `htb-cli` module in python. You can specify a machine
  name (by regex), and the script will query the HTB API to find the IP address
  and appropriate hostname.
