#!/usr/bin/perl

###############################################################################
###############################################################################
##
##  Copyright (C) Sistina Software, Inc.  1997-2003  All rights reserved.
##  Copyright (C) 2004 Red Hat, Inc.  All rights reserved.
##  
##  This copyrighted material is made available to anyone wishing to use,
##  modify, copy, or redistribute it subject to the terms and conditions
##  of the GNU General Public License v.2.
##
###############################################################################
###############################################################################

use Getopt::Std;
use Net::Telnet ();

# Get the program name from $0 and strip directory names
$_=$0;
s/.*\///;
my $pname = $_;


# WARNING!! Do not add code bewteen "#BEGIN_VERSION_GENERATION" and 
# "#END_VERSION_GENERATION"  It is generated by the Makefile

#BEGIN_VERSION_GENERATION
$FENCE_RELEASE_NAME="";
$REDHAT_COPYRIGHT="";
$BUILD_DATE="";
#END_VERSION_GENERATION


sub usage
{
    print "Usage:\n";  
    print "\n";
    print "$pname [options]\n";
    print "\n";
    print "Options:\n";
    print "  -a <ip>          IP address or hostname of NPS\n";
    print "  -h               usage\n";
    print "  -n <num>         Physical plug number on NPS\n";
    print "  -p <string>      Password if NPS requires one\n";
    print "  -o <operation>   Operation to perform (on, off, reboot)\n";
    print "  -q               quiet mode\n";
    print "  -T               test reports state of plug (no power cycle)\n";
    print "  -V               Version\n";

    exit 0;
}

sub fail
{
  ($msg)=@_;
  print $msg."\n" unless defined $opt_q;
  $t->close if defined $t;
  exit 1;
}

sub fail_usage
{
  ($msg)=@_;
  print STDERR $msg."\n" if $msg;
  print STDERR "Please use '-h' for usage.\n";
  exit 1;
}

sub version
{
  print "$pname $FENCE_RELEASE_NAME $BUILD_DATE\n";
  print "$REDHAT_COPYRIGHT\n" if ( $REDHAT_COPYRIGHT );

  exit 0;
}

if (@ARGV > 0) {
   getopts("a:hn:p:qTVo:") || fail_usage ;

   usage if defined $opt_h;
   version if defined $opt_V;

   fail_usage "Unkown parameter." if (@ARGV > 0);

   fail_usage "No '-a' flag specified." unless defined $opt_a;
   fail_usage "No '-n' flag specified." unless defined $opt_n;
   fail_usage "No '-p' flag specified." unless defined $opt_p;
   fail_usage "No '-o' flag specified." unless defined $opt_o;

} else {
   get_options_stdin();

   fail "failed: no IP address" unless defined $opt_a;
   fail "failed: no plug number" unless defined $opt_n;
   fail "failed: no password" unless defined $opt_p;
   fail "failed: no operation specified" unless defined $opt_o;
}

$t = new Net::Telnet;

$t->open($opt_a);

$expr = '/:|\n/';

while (1)
{
  ($line, $match) = $t->waitfor($expr);

  if ($line =~ /assword/)
  {
    fail "failed: no password" unless defined $opt_p;
    $t->print($opt_p);
    $expr = '/\n/';
  }

  elsif ($line =~ /v\d.\d+/)
  {
    $line =~ /\D*(\d)\.(\d+).*/;
    $ver1 = $1;
    $ver2 = $2;

    $t->waitfor('/(TPS|IPS|RPC|NPS)\>/'); 
    last;
  }
}


if (defined $opt_T)
{
  &test($t);
  exit 0;
}


# to be most certain of success, turn off, check for OFF status, turn ON, check
# for ON status
if (($opt_o eq "off") || ($opt_o eq "reboot")) {
  $t->print("/off $opt_n");
  ($line, $match) = $t->waitfor('/\(Y\/N\)|(TPS|IPS|RPC|NPS)\>/');

  if ($match =~ /Y\/N/)
  {
    $t->print("y");
    $t->waitfor('/(TPS|IPS|RPC|NPS)\>/');
  }

  $t->print("/s");

  while (1)
  {
    ($line, $match) = $t->waitfor('/\n|(TPS|IPS|RPC|NPS)\>/');

    if ($match =~ /(TPS|IPS|RPC|NPS)\>/)
    {
      print "failed: plug number \"$opt_n\" not found\n"
         unless defined $opt_q;
      exit 1;
    }
    
    $line =~ /^\s+(\d).*/;

    if ($1 == $opt_n)
    {
      $line =~ /^\s+(\d)\s+\|\s+\S+\s+\|\s+(\w+).*/; 

      $state = $2;

      if ($state =~ /OFF/)
      {
        $t->waitfor('/(TPS|IPS|RPC|NPS)\>/');
        last;
      }

      print "failed: plug not off ($state)\n"
         unless defined $opt_q;
      exit 1;
    }
  }
}


# at this point, failing to turn the machine back on shouldn't be a failure

if (($opt_o eq "on") || ($opt_o eq "reboot")) {
  $t->print("/on $opt_n");
  ($line, $match) = $t->waitfor('/\(Y\/N\)|(TPS|IPS|RPC|NPS)\>/');

  if ($match =~ /Y\/N/)
  {
    $t->print("y");
    $t->waitfor('/(TPS|IPS|RPC|NPS)\>/');
  }

  $t->print("/s");
  
  while (1)
  {
    ($line, $match) = $t->waitfor('/\n|(TPS|IPS|RPC|NPS)\>/');

    if ($match =~ /(TPS|IPS|RPC|NPS)\>/)
    {
      print "success: plug-on warning\n"
         unless defined $opt_q;
      exit 0;
    }

    $line =~ /^\s+(\d).*/;

    if ($1 == $opt_n)
    {
      $line =~ /^\s+(\d)\s+\|\s+\S+\s+\|\s+(\w+).*/;

      $state = $2;

      if ($state =~ /ON/)
      {
        $t->waitfor('/(TPS|IPS|RPC|NPS)\>/');
        last;
      }

      print "success: plug state warning ($state)\n"  
        unless defined $opt_q;

      exit 0;
    }
  }
}

print "success: $opt_o operation on plug $opt_n\n" unless defined $opt_q;

exit 0;



sub test
{
  local($t) = @_;

  $t->print("/s");

  while (1)
  {
    ($line, $match) = $t->waitfor('/\n|(TPS|IPS|RPC|NPS)\>/');

    if ($match =~ /(TPS|IPS|RPC|NPS)\>/)
    {
      print "failed: plug number \"$opt_n\" not found\n"
          unless defined $opt_q;
      exit 1;
    }

    $line =~ /^\s+(\d).*/;

    if ($1 == $opt_n)
    {
      $line =~ /^\s+(\d)\s+\|\s+\S+\s+\|\s+(\w+).*/;

      $state = $2;
      
      if ($state =~ /ON|OFF/)
      {
        print "success: current plug state \"$state\"\n" 
          unless defined $opt_q;
      }

      else
      {
        print "failed: unknown plug state \"$state\"\n"
          unless defined $opt_q;
      }
    
      last;
    }
  }
}

sub get_options_stdin
{
    my $opt;
    my $line = 0;
    while( defined($in = <>) )
    {
        $_ = $in;

        chomp;

        # strip leading and trailing whitespace
        s/^\s*//;
        s/\s*$//;

        # skip comments
        next if /^#/;

        $line+=1;
        $opt=$_;
        next unless $opt;

        ($name,$val)=split /\s*=\s*/, $opt;

        if ( $name eq "" )
        {
           print STDERR "parse error: illegal name in option $line\n";
           exit 2;
        }

        # DO NOTHING -- this field is used by fenced
        elsif ($name eq "agent" ) { }

        # FIXME -- deprecated.  use "port" instead.
        elsif ($name eq "fm" )
        {
            (my $dummy,$opt_n) = split /\s+/,$val;
            print STDERR "Deprecated \"fm\" entry detected.  refer to man page.\n";
        }

        elsif ($name eq "ipaddr" )
        {
            $opt_a = $val;
        }

	# FIXME -- depreicated residue of old fencing system
        elsif ($name eq "name" ) { }

        elsif ($name eq "passwd" )
        {
            $opt_p = $val;
        }
        elsif ($name eq "port" )
        {
            $opt_n = $val;
        }
        elsif ($name eq "option" )
        {
            $opt_o = $val;
        }
        # elsif ($name eq "test" ) 
        # {
        #    $opt_T = $val;
        # } 

        # FIXME should we do more error checking?  
        # Excess name/vals will be eaten for now
        else
        {
           fail "parse error: unknown option \"$opt\"\n";
        }
    }
}
