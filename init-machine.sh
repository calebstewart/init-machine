#!/usr/bin/env bash

GREEN=`tput setaf 2`
RED=`tput setaf 1`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
RST=`tput sgr0`

CMD="$0"
APIKEY_NAME="./.htb-key"
CONNECTION_NAME="Hack the Box"
INTERFACE="tun0"
HOSTNAME=""

# Print an error message to stderr
function error {
	echo "[${RED}error${RST}] $@" 1>&2
	exit 1
}

# Print a warning message to stderr
function warning {
	echo "[${YELLOW}warning${RST}] $@" 1>&2
}

# Print some info to stdout
function info {
	echo "[${BLUE}info${RST}] $@"
}

# Print usage information
function print_usage {
	cat <<EOF
Usage: $CMD [OPTION]... (machine_regex|machine_id|ip)

Initialize a new Hack the Box machine directory structure and perform initial
scans.

Options:
	-h               display this help message
	-t               perform TCP scans (default)
	-u               perform UDP scans
	-b               search for the given machine on hack the box
	-n               machine name (used for /etc/hosts and directory)
	-k               hack the box api key location (default: $APIKEY_NAME)
	-i               interface for masscan (default: $INTERFACE)

Parameters:
	machine_regex    \`grep -iE\` compatible regex for machine name
	machine_id       numeric machine identifier
	ip               IP address of non-hack-the-box machine 
EOF
}

RUN_TCP=1
RUN_UDP=0
ALL_PORTS=0

while getopts ":htubk:n:i:" opt; do
	case ${opt} in
		t )
			RUN_TCP=1
			;;
		u )
			RUN_UDP=1
			;;
		h )
			print_usage
			exit 0
			;;
		b )
			HACK_THE_BOX=1
			;;
		n )
			HOSTNAME="$OPTARG"
			;;
		k )
			if ! [ -f "$OPTARG" ]; then
				error "$OPTARG: no such file or directory"
			fi
			APIKEY_NAME=$OPTARG
			;;
		i )
			INTERFACE=$OPTARG
			;;
		\? )
			print_usage
			exit 1
			;;
	esac
done

# Shift out short options
shift $((OPTIND-1))

# Ensure a machine was specified
if [ "$#" -ne 1 ]; then
	echo "error: no machine specified" >&2
	print_usage
	exit 1
fi

# Fetch the information on the given box via HTB API
if ! [[ -z $HACK_THE_BOX ]]; then
	
	# Fetch the HTB API Key
	APIKEY=`cat $APIKEY_NAME`

	if ! [[ $1 =~ '^[0-9]+$' ]]; then
		machine=`HTB_API_KEY=$APIKEY hackthebox.py list machines active | grep -E "$1" | head -n1`
		if [ -z "$machine" ]; then
			echo "error: $1: no matching machine found" >&2
			exit 1
		fi
		machine_id=`echo "$machine" | tr -d ' ' | cut -d'|' -f2`
	else
		machine_id = $1
	fi

	# Get the machine information
	machine_info=`HTB_API_KEY=$APIKEY hackthebox.py get machine $machine_id 2>/dev/null || echo -n no`
	if [ "$machine_info" = "no" ]; then
		error "invalid machine id: $machine_id"
	fi

	# Parse machine name and address
	NAME=`echo -n "$machine_info" | grep -e "^NAME: " | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]' | tr -d '\n'`
	ADDRESS=`echo -n "$machine_info" | grep -e "^IP: " | cut -d' ' -f2 | tr -d '\n'`
	HOSTNAME="$NAME.htb"

	# Ensure we can or are connected to the hack the box VPN
	if ! nmcli c s --active | grep "$CONNECTION_NAME" > /dev/null; then
		nmcli connection up "$CONNECTION_NAME" || \
			error "could not connect to vpn: $CONNECTION_NAM"
	fi
else
	# Ensure we know enough about the machine
	if ! [[ $1 =~ '[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}' ]]; then
		error "$1: expected an ipv4 address"
	fi

	if [ -z "$HOSTNAME" ]; then
		warning "no hostname provided; using ipv4 address"
		HOSTNAME=$1
	fi

	# Save the address for later use
	ADDRESS="$1"
fi

info "setting up environment for: $HOSTNAME"
warning "you may be prompted for sudo password (for /etc/hosts and raw network device access)"

# Install hostname in /etc/hosts
if ! [ "$ADDRESS" = "$HOSTNAME" ]; then
	if ! grep -E "$ADDRESS\s+$HOSTNAME" /etc/hosts 2>&1 >/dev/null; then
		info "installing $HOSTNAME in /etc/hosts"
		hosts_line=`echo -e "# init-machine.sh - $NAME\n$ADDRESS\t$HOSTNAME"`
		sudo sh -c "cat - >>/etc/hosts"<<END
# Hack the Box - $NAME
$ADDRESS	$HOSTNAME
END
	else
		info "machine already added to /etc/hosts"
	fi
else
	warning "no hostname provided; not adding to /etc/hosts"
fi

# Creating common directory tree
info "setting up directory tree"
mkdir -p "./$HOSTNAME/scans"
mkdir -p "./$HOSTNAME/artifacts"
mkdir -p "./$HOSTNAME/exploits"

if ! [ -f "./$HOSTNAME/README.md" ]; then
	cat <<END >"./$HOSTNAME/README.md"
# $HOSTNAME - $ADDRESS

This machine has been added to /etc/hosts as $HOSTNAME. Basic nmap scans are stored in [./scans](./scans).
END
fi

# Enter the directory tree
pushd "./$HOSTNAME" >/dev/null

# Run TCP scans if requested
if [ "$RUN_TCP" -eq "1" ] && ! [ -f "scans/masscan-tcp.grep" ]; then
	info "enumerating all tcp ports w/ masscan"
	sudo masscan -p 1-65535 $ADDRESS -p 0-65535 --max-rate 1000 -oG scans/masscan-tcp.grep -e "$INTERFACE"

	# grab the list of open ports
	ports=`grep "open" ./scans/masscan-tcp.grep | awk '{ print $7 }' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//g'`
	
	if [ -z "$ports" ]; then
		warning "no open tcp ports detected!"
	else
		# Start nmap scan for these ports
		info "scanning open tcp ports w/ nmap ($ports)"
		nmap -Pn -T5 -sV -A -p "$ports" -oN ./scans/open-tcp.nmap $HOSTNAME
	fi
fi

# Run UDP scans if requested
if [ "$RUN_UDP" -eq "1" ] && ! [ -f "scans/masscan-udp.grep" ]; then
	info "enumerating all udp ports w/ masscan"
	sudo masscan --udp-ports 1-65535 $ADDRESS --max-rate 1000 -oG scans/masscan-udp.grep -e tun0

	# grab the list of open ports
	ports=`grep "open" ./scans/masscan-udp.grep | awk '{ print $7 }' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//g'`
	
	if [ -z "$ports" ]; then
		warning "no open udp ports detected!"
	else
		# Start nmap scan for these ports
		info "scanning open udp ports w/ nmap ($ports)"
		nmap -Pn -T5 -sU -sV -A -p "$ports" -oN ./scans/open-udp.nmap $HOSTNAME
	fi
fi

# Go back
popd >/dev/null
