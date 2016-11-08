#!/usr/bin/perl -w
#
# Copyright (C) 2016 Internet Neutral Exchange Association Company Limited By Guarantee.
# All Rights Reserved.
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, version 2.0 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License v2.0
# along with this program.  If not, see:
#
# http://www.gnu.org/licenses/gpl-2.0.html
#

use strict;
use Data::Dumper;
use Getopt::Long;

my $action = '';

GetOptions (
	"action=s"		=> \$action,
);

$action = lc($action);
if ($action !~ /^(renumber|shutdown|remove)$/) {
	$action = "renumber";
}

my $curinterface;
my $curaccesslist = "";
my $curprefixlist = "";
my $accesslistrenumbered = 0;
my $prefixlisthash;
my @accesslist;
my $seenbgpneighbor;
my $multilineneighbor = 0;

while (<>) {
	if (/^interface\s+(.*)/) {
		$curinterface = $1;
	}

	# ip address 193.242.111.x 255.255.255.0
	# ip address 193.242.111.x/24
	# ipv4 address 193.242.111.x/24
	if (/^\s+ip\s+address\s+(193.242.111.\d+)\s+255.255.255.128/) {
		my $ip = oldtonew($1);
		if ($action eq "renumber") {
			print <<EOF;
interface $curinterface
 ip address $ip 255.255.254.0	
EOF
		}
	}
	if (/^\s+(ip|ipv4)\s+address\s+(193.242.111.\d+)\/(\d+)/) {
		my $ip = oldtonew($2);
		if ($action eq "renumber") {
			print <<EOF;
interface $curinterface
 $1 address $ip/23
EOF
		}
	}

	if (/^router bgp/) {
		print "\n$_";
		next;
	}

	if (/address-family ipv4(\s*unicast)?$/ && $action eq "renumber" && !$multilineneighbor) {
		print $_;
		next;
	}
	
	if (/(\s+)neighbor\s+(193.242.111.\d+)\s+(.*)/) {
		my $spaces = $1;
		my $oldip = $2;
		my $newip = oldtonew($2);
		my $restofline = $3;

		if (!$restofline) {
			$multilineneighbor = 1;
		}

		if ($action eq "shutdown") {
			!$seenbgpneighbor->{$oldip} && print $spaces."neighbor $oldip shutdown\n"
		} elsif ($action eq "remove") {
			!$seenbgpneighbor->{$oldip} && print $spaces."no neighbor $oldip\n"
		} elsif ($action eq "renumber") {
			print $spaces."neighbor $newip $restofline\n"
		}
		
		$seenbgpneighbor->{$oldip} = 1;
		next;
	}

	if (/(\s+)neighbor\s+/) {
		$multilineneighbor = 0;
	}

	if (/^\s+\!/ && $multilineneighbor) {
		if ($action eq "renumber") {
			print $_;
		}
		$multilineneighbor = 0;
	}
	
	if ($multilineneighbor && $action eq "renumber") {
		print $_;
	}

	# handle access-list config lines
	if ((/^\s*\!/ || /^ip access-list/) && $curaccesslist) {
		if ($accesslistrenumbered && $action eq "renumber") {
			print "!\n";
			print join ("\n", @accesslist);
			print "\n";
		}
		@accesslist = ();
		$curaccesslist = 0;
		$accesslistrenumbered = 0;
	}

	if (/^(ip|ipv4) access-list\s+(.*)/) {
		@accesslist = ();
		$curaccesslist = chomp($_);
		push (@accesslist, "no $_");
		push (@accesslist, $_);
		next;
	}

	if ($curaccesslist) {
		chomp;
		my $line = $_;
		if (/193\.242\.111\./) {
			$accesslistrenumbered = 1;
		}
		# permit tcp 193.242.111.0/25 eq bgp 193.242.111.0/25
		$line =~ s/193\.242\.111\.(\d+)\/25/185.6.36.$1\/23/g;
		# sequence 200 permit tcp 193.242.111.0 0.0.0.127 eq bgp 193.242.111.0 0.0.0.127
		$line =~ s/193\.242\.111\.(\d+)\s+0.0.0.127/185.6.36.$1 0.0.1.255/g;
		push (@accesslist, $line);
		next;
	}
	
	if (/^(ip|ipv4) prefix-list\s+(\S+)\s+/) {
		my $list = $2;
		if (/193\.242\.111\./) {
			$prefixlisthash->{$list}->{renumbered} = 1;
			s/193\.242\.111\.(\d+)\/25/185.6.36.$1\/23/g;
		}
		push (@{$prefixlisthash->{$list}->{entries}}, $_);
	}
}

if ($action eq "renumber") {
	foreach my $plkey (keys %{$prefixlisthash}) {
		next unless (defined ($prefixlisthash->{$plkey}->{renumbered}));
	
		print "!\nno ip prefix-list $plkey\n";
		print join ('', @{$prefixlisthash->{$plkey}->{entries}});
	}
}

exit;

sub oldtonew {
	my ($addr) = @_;
	
	if ($addr =~ /193.242.111.(\d+)/) {
		$addr = "185.6.36.$1";
	}
	
	return $addr;
}
