#!/usr/bin/perl
# -------------------------------------------------------------------------------
# neobitti_update_ip.pl
#
# Version 1.0 - 16.01.2012
#
# PERL script to dynamically update the IP of a host via the cPanel-API. This
# script was written to work with the Finnish hoster Neobitti but it might work
# with other hosters which use cPanel too.
#
# Copyright (C) 2012 Stefan Gofferje - http://stefan.gofferje.net/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# -------------------------------------------------------------------------------
use strict;
use LWP::UserAgent;
use MIME::Base64;
use XML::Simple;
use XML::SAX;
use Data::Dumper;
use Net::UPnP::ControlPoint;
use Net::UPnP::GW::Gateway;


# --- Command line parameters ------------------------------------------------
my $param_domain=$ARGV[0]; # Ths is your domain hosted in cPanel (ex: lalala.com)
my $param_host=$ARGV[1];   # This is your host (mywebserver.lalala.com)

print $param_domain;
print $param_host;


# --- cPanel information uncomment and fill -----------------------------------
# i.e. cpanel.lalala.com
#my $cpanel_domain = "";

#username for your cpanel
#my $user = "";

#password for your cpanel
#my $pass = "";

#location of your log file
#my $log_file = "";

# ------------ dont modifify anything under this line -------------------------

my $auth = "Basic " . MIME::Base64::encode( $user . ":" . $pass );


# --- Deactivate SSL certificate validation ----------------------------------
# This is ugly but neccessary because Neobitti uses self-signed SSL
# certificates which will fail validation
my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
my $browser = LWP::UserAgent->new;

# add/update a parser
XML::SAX->add_parser(q(XML::SAX::PurePerl));


# --- Main procedure ---------------------------------------------------------
my $newip = getnewip;
if ($newip eq "0") {
	log_this ( "Unable to retrieve current IP from Gateway");
	die;
};
#log_this ("Trying to find the linenumber for $param_host in $param_domain...");
my $line=getlinenumber_a($param_domain,$param_host, $newip);
if ( ($line ne "0") && ($line ne "") && ($line ne "-1")) {
  log_this ("Trying to update IP...");
  my $result=setip ($param_domain,$line,$newip);
  if ($result eq "1") {
    log_this ("Update successful!");
  } else {
    log_this ("$result");
  }
} 
elsif ( $line eq "0") {
	log_this ("Error - check domain and hostname!");}
elsif ( $line eq "-1") {
	log_this ("Address has not changed, not forcing");}


	
	
# --------------------------------- helpers ------------------------------------

sub log_this {
	my $s = $_[0];
	$s = localtime(time()) . " - " . $s;
	open(my $fh, '>>', $log_file) or die "Could not open file '$log_file' $!";
	print $fh $s ."\n";
	close $fh;
	
	return;
}

sub getnewip {

	my $request = HTTP::Request->new( GET => "https://www.cpanel.net/myip/" );
	my $response = $browser->request($request);
	my $ip_address = $response->content;
	$ip_address =~ s/\s+//g;
	log_this ( sprintf "Gateway has IP address %s\n", $ip_address );
	return ($ip_address);
}

# --- Find out the linenumber for the A-record we want to change from the cpanel-------------
sub getlinenumber_a {
	my $domain=$_[0];
	my $hostname=$_[1].".";
	my $newip=$_[2];
	
	my $oldip="";
	my $xml = new XML::Simple;

	my $request = HTTP::Request->new( GET => "https://$cpanel_domain:2083/xml-api/cpanel?cpanel_xmlapi_module=ZoneEdit&cpanel_xmlapi_func=fetchzone&domain=$domain" );
	$request->header( Authorization => $auth );
	my $response = $ua->request($request);
	my $zone = $xml->XMLin($response->content);
	my $linenumber="";
	if ($zone->{'data'}->{'status'} eq "1") {
		my $count = @{$zone->{'data'}->{'record'}};
		for (my $item=0;$item<=$count;$item++) {
			my $name=$zone->{'data'}->{'record'}[$item]->{'name'};
			my $type=$zone->{'data'}->{'record'}[$item]->{'type'};
			if ( ($name eq $hostname) && ($type eq "A") ) {
			  $linenumber=$zone->{'data'}->{'record'}[$item]->{'Line'};
			  $oldip=$zone->{'data'}->{'record'}[$item]->{'record'};
			  log_this ("Found $hostname in line $linenumber with IP $oldip"); # DEBUG
			}
		}
	} else {
		$linenumber="0";
		log_this ($zone->{'event'}->{'data'}->{'statusmsg;'});
	}
	log_this ("Old IP: $oldip and Current IP: $newip");
	if ( $oldip eq $newip ) {
		log_this ("They are equal");
		return("-1");
	}
  return($linenumber);
}



# --- Change the IP address record ---------------------------
sub setip {
  my $domain=$_[0];
  my $linenumber=$_[1];
  my $newip=$_[2];
  my $result="";
  my $xml = new XML::Simple;
  
  
  my $request = HTTP::Request->new( GET => "https://$cpanel_domain:2083/xml-api/cpanel?cpanel_xmlapi_module=ZoneEdit&cpanel_xmlapi_func=edit_zone_record&domain=$domain&line=$linenumber&address=$newip" );
  $request->header( Authorization => $auth );
  my $response = $ua->request($request);
 
  my $reply = $xml->XMLin($response->content);
  if ($reply->{'data'}->{'status'} eq "1") {
    $result="1";
  } else {
    $result=$reply->{'data'}->{'statusmsg'};
  }
  return($result);
}
