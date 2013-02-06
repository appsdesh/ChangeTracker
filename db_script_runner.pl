#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Std;
use Data::Dumper;
use DBI;

#
# Created by: Apoorva Deshpande
#

my %opts;
our ($opt_h, $opt_H, $opt_u, $opt_p, $opt_P, $opt_D, $opt_f, $opt_d);
my $dbh = 0;
my $debug = 0;

my $sth;

# Base table script
my $base_table_script;
my $base_table_name 		= "config_scripts";

my $sql_script_name_pattern = "(sql_(\\d{0,10})_.*.sql)";

# Setting it in the config function based on the folder path
my $sql_local_pattern;		

main();
sub main {
	print "Starting the update script ...\n";
	print "Reading the configuration ...\n";
	read_config();
	db_connect();
	setup_script_config_table();
	my $largest = read_from_table();
	my $script_map = read_local_scripts();
	run_remaining_scripts($largest, $script_map);
	db_disconnect();
	print "Finished execution ...\n";
	return;
}

sub db_disconnect {
	$dbh->disconnect();
	print "Disconnecting connection .. \n";
	return;
}
sub execute_sql {
	my $sql_query = shift;
	print $sql_query . " \n";
	print `$sql_query` . " \n";
	return;
}
sub run_remaining_scripts {
	my $largest = shift;
	my $script_map = shift;
	my $remaining;

	print "Preparing script execution (if any) .. \n";
	foreach(keys (%$script_map)) {
		if( $largest < $_ ) {
			$remaining->{$_} = $script_map->{$_};
			print "[$remaining->{$_}] ready for execution ..\n";
		}
	}
	print "Nothing to update .. \n" if(not $remaining);
	foreach(sort { $a <=> $b } keys %$remaining) {
		eval {
			print "Executing script [$remaining->{$_}] ..\n";
			my $query = "mysql -h$opt_H -p$opt_p -u$opt_u -p$opt_P $opt_D < $remaining->{$_}";
			execute_sql($query);
			my $sql = "INSERT INTO $base_table_name (id, script_name, create_date)
			VALUES ($_, '$remaining->{$_}', CURDATE())";
			$sth = $dbh->prepare($sql);
			$sth->execute() or die "SQL script [$_] failed : $DBI::errstr";
		}; 
		if($@) {
			die "Error in executing script [$remaining->{$_}] : $@";
		}
	}
	return;
}

sub get_map {
	my $list = shift;
	my $nums;
	foreach (@$list) {
		print "Checking [$_] .. \n";
		if($_ =~ $sql_script_name_pattern) {
			if(!$nums->{$2}) {
				# $2 is a digit, $1 is a script_name.sql, $_ is an absolute name
				$nums->{$2} = $_;
			} else {
				die "Potentially conflicting scripts [$_] and [$nums->{$1}] .. Resolve before proceeding\n";
			}
		} else {
			print "Attention: Skipping [$_] execution as naming convention is NOT enforced ..\n";
		}
	}
	return $nums;
}

sub read_local_scripts {
	my @scripts = glob($sql_local_pattern);
	my $len = scalar @scripts;
	print "Number of local script in the folder [$len]\n";
	my $script_map = get_map(\@scripts);
	return $script_map;
}

sub read_from_table {
	my @files;
	my $largest = 0;
	my $len = 0;
	my $sql_largest = "select max(id) from $base_table_name";
	my $sql_count	= "select count(*) from $base_table_name";
	
	my $sth = $dbh->prepare($sql_largest);
	$sth->execute();
	if( $sth->execute() ) {
            while( my $t = $sth->fetchrow_array() ) {
               $largest = $t if($t);
			}
	}
	
	$sth = $dbh->prepare($sql_count);
	$sth->execute();
	if( $sth->execute() ) {
            while( my $t = $sth->fetchrow_array() ) {
               $len = $t if($t);
			}
	}
	
	print "Number of SQL file entries in the database [$len]\n";
	return $largest;
}

sub create_script_config {
	print "Table does not exist ..\n";
	eval {
		my $sql_query = "mysql -h$opt_H -p$opt_p -u$opt_u -p$opt_P $opt_D < $base_table_script";
		execute_sql($sql_query);
		print "Base table created..\n";
	};
	if($@) {
		die "Error while executing script: $@";
	}
}

sub setup_script_config_table {
	print "checking if table exists .. \n";
	my $sql         = "show tables like '$base_table_name'";
    my $sth         = $dbh->prepare( $sql );
       my $exists      = 0;
       if( $sth->execute() ) {
            while( my $t = $sth->fetchrow_array() ) {
                if( $t =~ /^$base_table_name$/ ) { print "Table exists ..\n";return; }
			}                        
       }
	   create_script_config($base_table_name) if(not $exists);
	   return;
}

sub db_connect {
	$dbh = DBI->connect("DBI:mysql:$opt_D:$opt_H:$opt_p","$opt_u","$opt_P")
	or die "Connection Error: $DBI::errstr\n";
	return;
}

sub read_config() {
	getopt('dhf:u:P:H:p:D:');
	
	print_help() if($opt_h);
	print_help() if(not $opt_D);
	print_help() if(not $opt_P);
	$opt_u = "root" if(not $opt_u);
	$opt_H = "localhost" if(not $opt_H);
	$opt_p = 3306 if(not $opt_p);
	$opt_f = "./" if(not $opt_f);
	$debug = 1   if($opt_d);
	$sql_local_pattern = $opt_f."*.sql";
	$base_table_script = $opt_f."base_table_script.sql";
	return;
}

sub print_help {
print <<USAGE

    Usage: $0 [-u] <username> -P <password> -p <port> -H <server> -D <database> -f <path> 

    Options
    -------
    -D <database>     Name of the Database
    -u <username>     Username for the database           (optional)
    -P <password>     Password for the database           (optional)
    -p <port>         Database server port (ex: 80)       (optional)
    -H <server>       Database host (ex: 10.12.132.188)   (optional)
    -f <folder_path>  Absolute path of SQL script folder
                     (eg. /data01/deploy/)                (optional)
    -d                Debug                               (optional)

    This script is used for sql script execution.
    For all the optional inputs defaults will kick in. 

USAGE
;
    exit 1;
}