#!/usr/bin/perl
use strict;
use utf8;

# Dieses Programm wird dazu verwendet, die Log-Funktionsaufrufe in Vala zu "korrigieren"

my $dir = shift;
my $mdb = shift;
my $component = shift;
my $c_compiler = shift;

# Das debug-Flag kann 1, 0 oder nix sein. Wenn es 1 ist, werden alle Debug-Ausgaben gelassen, sonst entfernt
my $debug = shift;
if (!defined $debug || $debug ne "1")
{
  $debug = "0";
}

my $architektur = `uname -m`;
if ( $c_compiler =~ /(i686|x86_64)[^\/]+mingw[^\/]+$/ )
{
  $architektur = $1;
}
$architektur =~ s/\s//g;
$architektur =~ s/i686/(32-Bit)/g;
$architektur =~ s/x86_64/(64-Bit)/g;

my @merge_mdbs = @ARGV;

if ($dir eq "")
{
  $dir = "./";
  warn "No directory given - using $dir!";
}
if ($mdb eq "")
{
  $mdb = "messages.mdb";
  warn "No filename for message database given - using $mdb!";
}

if ( !defined $component || $component eq "" )
{
  warn "No component specified! Cannot run without component!";
  exit( 1 );
}

my $git_version = `git rev-parse HEAD`;
$git_version =~ s/\n//g;
my %messages;
my $message_id = 0;

if (-e $mdb)
{
  # Reading MDB file...
  # Structure of MDB lines is:
  # <component>\x01<message_id>\x01<message>
  unless(open(MDB, "<$mdb"))
  {
    warn "Could not open $mdb for reading! $!";
    exit(1);
  }
  binmode MDB;
  my $mdb_line;
  while ($mdb_line = <MDB>)
  {
    $mdb_line =~ s/\n$//;
    if ($mdb_line =~ /^\s*$/ || $mdb_line =~ /^\s*#/)
    {
      next;
    }
    my @tokens = split( /\x01/, $mdb_line );
    if ( $#tokens != 2 )
    {
      warn "Message database $mdb has wrong structure!";
      warn "Invlid line is $mdb_line";
    }
    $messages{ $tokens[ 0 ] }->{ $tokens[ 2 ] } = $tokens[ 1 ];
    if ( $debug )
    {
      #print "$tokens[ 0 ]: $tokens[ 2 ] = $tokens[ 1 ]\n";
    }
    if ( $message_id < $tokens[ 1 ] )
    {
      $message_id = $tokens[ 1 ];
    }
  }
  close MDB;
}

# Check if other MDBs should be merged into this MDB...
foreach my $merge_mdb ( @merge_mdbs )
{
  if ( $debug )
  {
    print "Merging $merge_mdb\n";
  }
  unless( open( MRG, "<$merge_mdb" ) )
  {
    warn "Could not merge $merge_mdb into $mdb! $!";
    exit( 1 );
  }
  while ( my $line = <MRG> )
  {
    $line =~ s/\n$//;
    if ( $line =~ /^\s*$/ || $line =~ /^\s*#/ )
    {
      next;
    }
    my @tokens = split( /\x01/, $line );
    if ( $#tokens != 2 )
    {
      warn "Message database $mdb has wrong structure!";
      warn "Wrong line: $line";
    }
    $messages{ $tokens[ 0 ] }->{ $tokens[ 2 ] } = $tokens[ 1 ];
    if ( $debug )
    {
      #print "$tokens[ 0 ]: $tokens[ 2 ] = $tokens[ 1 ]\n";
    }
  }
  close MRG;
}


if ( !-d $dir )
{
  parse_valafile( $dir, $dir . ".preprocessed.vala" );
}
else
{
  unless( opendir( DIR, $dir ) )
  {
    warn "Could not open Directory $dir! $!";
    exit( 1 );
  }
  my @files = readdir( DIR );
  foreach my $f ( @files )
  {
    if ( ( ! -d $f ) && ( $f =~ /\.vala$/i ) )
    {
      parse_valafile( $dir . $f );
    }
  }
  closedir DIR;
}

unless( open( MDB, ">$mdb" ) )
{
  warn "Could not open $mdb for writing! $!";
  exit( 1 );
}
binmode MDB;
foreach my $comp ( keys %messages )
{
  foreach my $msg ( keys %{ $messages{ $comp } } )
  {
    my $id = $messages{ $comp }->{ $msg };
    print MDB "$comp\x01$id\x01$msg\n";
  }
}

close MDB;

sub parse_valafile
{
  my $vfile = shift;
  my $voutfile = shift || $vfile;

  print "Parsing Vala-File $vfile\n";

  my @lines;
  unless(open(FIN, "<$vfile"))
  {
    warn "Could not open $vfile for reading! $!";
    exit(1);
  }
  my $line;
  my $log_preprocessed = 0;
  while ($line = <FIN>)
  {
    if ( $line eq "/* PREPROCESSED - DYNAMIC */\n" )
    {
      $log_preprocessed = 1;
    }
    if ( $line eq "/* PREPROCESSED */\n" )
    {
      close FIN;
      print "Skipping $vfile\n";
      return;
    }
    push(@lines, $line);
  }
  close FIN;

  unless(open(FOUT, ">$voutfile"))
  {
    warn "Could not open $vfile for writing! $!";
    exit(1);
  }

  my $line_number = 0;

  print "Git-Version $git_version\n";

  # Diese Variable gibt an, welchen Log-Level (debug, info, warning, error) die letzte Log-Message hatte
  my $previous_log_level = "";

  # Erstellen eines Datums mit Zeit
  my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime( time );
  my $date_time = sprintf( "%02d.%02d.%04d %02d:%02d:%02d", $mday, $mon + 1, $year + 1900, $hour, $min, $sec );

  # Wenn das Source-File die Git-Version oder das Datum enthält, wird es als dynamisch preprocessed markiert
  my $dynamic_file = 0;

  while ($line = shift(@lines))
  {
    if ( $line =~ /:::GITVERSION:::/ || $line =~ /:::DATETIME:::/ || $line =~ /:::ARCHITEKTUR:::/ )
    {
      $line =~ s/:::GITVERSION:::/$git_version/g;
      $line =~ s/:::DATETIME:::/$date_time/g;
      $line =~ s/:::ARCHITEKTUR:::/$architektur/g;
      $dynamic_file = 1;
    }
    $line_number ++;
    if ( $log_preprocessed == 0 )
    {
      $line =~ s/\\"/\x01/g;
      if ($debug ne "1" && $line =~ /^[^\.]*(GLib\.)?debug\(.*\);/)
      {
        $line = $` . $';
        next;
      }
      elsif ($line =~ /(DocPipe|this|DMLogger|DocuMatrix|Core)\.log\.(debug|info|warning|error|fatal)\s*\(\s*([0-9]+)\s*,\s*(true|false)\s*,\s*("[^"]*"\s*|[^\s]+\s*)(\)|,)/i)
      {
        my $package = $1;
        my $func = $2;
        my $trace_level = $3;
        my $concat = $4;
        my $message = $5;
        my $nach_string = $6;
        my $davor = $`;
        my $danach = $';
        my $my_id;

        if ($debug ne "1" && $previous_log_level eq "debug")
        {
          #next;
        }

        if ($davor !~ /\s*\/\/\s*$/)
        {
          if ($message !~ /^"/)
          {
            $nach_string = ", $message" . $nach_string;
            $message = "\${1}";
          }
          else
          {
            $message =~ /^\s*"([^"]*)"\s*$/;
            $message = $1;
          }
          if ( defined $messages{ $component }->{ $message } )
          {
            #print "message already defined\n";
            $my_id = $messages{ $component}->{ $message };
          }
          else
          {
            #print "new message\n";
            $message_id ++;
            $my_id = $message_id;
            $messages{ $component }->{ $message } = $my_id;
          }
          $line = "";
          if ($func eq "debug")
          {
            $line = "if ($package.log_trace_level >= $trace_level) { ";
            $danach =~ s/\n$//;
          }
          $line .= $davor . "$package.log.$func( \"$component\", \"$vfile\", $line_number, \"$git_version\", $trace_level, $concat, $my_id$nach_string$danach";
          if ($func eq "debug")
          {
            $line .= " }\n";
          }
        }
      }
      elsif ( $line =~ /(DocPipe|this|DMLogger|DocuMatrix|Core)\.t\s*\(\s*("[^"]+"|[^\s]+)\s*,\s*("[^"]*"|[^\s]+)\s*(\)|,)/i )
      {
        my $package = $1;
        my $caption = $2;
        my $message = $3;
        my $nach_string = $4;
        my $danach = $';
        my $davor = $`;

        if ( $davor !~ /\s*\/\/\s*$/ )
        {
          if ( $message !~ /^\s*"/ )
          {
            $nach_string = ", $message" . $nach_string;
            $message = "\${1}";
          }
          else
          {
            $message =~ /^\s*"([^"]*)"\s*$/;
            $message = $1;
          }

          warn "message: $message - caption: $caption";
          if ( !defined $messages{ $component }->{ $message } && $caption =~ /^"(.*)"$/ )
          {
            $messages{ $component }->{ $message } = $1;
          }
        }
        $line = $davor . "$package.t( \"$component\", $caption, \"$message\" $nach_string$danach";
      }
    }
    $line =~ s/\x01/\\"/g;
    print FOUT $line;
  }
  if ( $dynamic_file )
  {
    print FOUT "/* PREPROCESSED - DYNAMIC */\n";
  }
  else
  {
    print FOUT "/* PREPROCESSED */\n";
  }

  close FOUT;
}
