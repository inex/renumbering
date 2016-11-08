# Tools for INEX renumbering project

```convert-config.pl``` is a script which parses configuration files from
Cisco IOS, Brocade and Quagga routers and emits suggested configuration
changes to help migrating from 193.242.111.0/25, the old INEX LAN1 address
range to 185.6.36.0/25, the range deployed in November 2016.

Copyright (C) 2016 Internet Neutral Exchange Association Company Limited By
Guarantee, all rights reserved.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

```convert-config.pl``` should not be used for XR or JunOS.

```convert-config.pl``` depends only the Getopt::Long perl library.

This program takes a single argument to specify the action that the code
should take and takes input from stdin.  The input stream should be a copy
of the full router configuration.

This produces configuration to shut down all the old INEX LAN1 BGP sessions:

```
 ./convert-config.pl --action=shutdown < routerconfigfile.conf
```

This argument creates baseline configuration to renumber INEX LAN1 BGP
sessions and both prefix-lists and access-lists:

```
./convert-config.pl --action=renumber < routerconfigfile.conf
```

This command produces configuration to remove all the old INEX LAN1 BGP
sessions:

```
./convert-config.pl --action=remove routerconfigfile.conf
```
