#!/usr/bin/perl

# Dieses Programm wird dazu verwendet, die Log-Funktionsaufrufe in Vala zu "korrigieren"

my $dir = shift;
my $mdb = shift;
my $output_file = shift;

# Das debug-Flag kann 1, 0 oder nix sein. Wenn es 1 ist, werden alle Debug-Ausgaben gelassen, sonst entfernt
my $debug = shift;
if (!defined $debug || $debug ne "1")
{
  $debug = "0";
}
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

my $git_version = `git rev-parse HEAD`;
$git_version =~ s/\n//g;
my %messages;
my $message_id = 0;

if (-e $mdb)
{
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
    my @tokens = split(/\x01/, $mdb_line);
    $messages{$tokens[0]} = $tokens[1];
    print "$tokens[1] = $tokens[0]\n";
    if ($message_id < $tokens[1])
    {
      $message_id = $tokens[1];
    }
  }
  close MDB;
}

if ( !-d $dir )
{
  parse_valafile( $dir, $dir . ".preprocessed.vala" );
}
else
{
  unless(opendir(DIR, $dir))
  {
    warn "Could not open Directory $dir! $!";
    exit(1);
  }
  my @files = readdir(DIR);
  foreach my $f (@files)
  {
    if ((! -d $f) && ($f =~ /\.vala$/i))
    {
      parse_valafile($dir . $f);
    }
  }
  closedir DIR;
}

unless(open(MDB, ">$mdb"))
{
  warn "Could not open $mdb for writing! $!";
  exit(1);
}
binmode MDB;
foreach my $k (keys %messages)
{
  #print "Message $k = $messages{$k}\n";
  print MDB "$k\x01$messages{$k}\n";
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
  ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime( time );
  my $date_time = sprintf( "%02d.%02d.%04d %02d:%02d:%02d", $mday, $mon + 1, $year + 1900, $hour, $min, $sec );

  # Wenn das Source-File die Git-Version oder das Datum enthält, wird es als dynamisch preprocessed markiert
  my $dynamic_file = 0;

  while ($line = shift(@lines))
  {
    if ( $line =~ /:::GITVERSION:::/ || $line =~ /:::DATETIME:::/ )
    {
      $line =~ s/:::GITVERSION:::/$git_version/g;
      $line =~ s/:::DATETIME:::/$date_time/g;
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
      elsif ($line =~ /(DocPipe|this|DMLogger|DocuMatrix|Core)\.log\.(debug|info|warning|error)\s*\(\s*([0-9]+)\s*,\s*(true|false)\s*,\s*("[^"]*"\s*|[^\s]+\s*)(\)|,)/i)
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
          if ( defined $messages{ $message } )
          {
            #print "message already defined\n";
            $my_id = $messages{$message};
          }
          else
          {
            #print "new message\n";
            $message_id ++;
            $my_id = $message_id;
            $messages{$message} = $my_id;
          }
          $line = "";
          if ($func eq "debug")
          {
            $line = "if ($package.log_trace_level >= $trace_level) { ";
            $danach =~ s/\n$//;
          }
          $line .= $davor . "$package.log.$func(\"$vfile\", $line_number, \"$git_version\", $trace_level, $concat, $my_id$nach_string$danach";
          if ($func eq "debug")
          {
            $line .= " }\n";
          }
        }
      }
      elsif ( $line =~ /(DocPipe|this|DMLogger|DocuMatrix|Core)\.t\s*\(\s*("[^"]*"|[^\s]+)\s*(\)|,)/i )
      {
        my $package = $1;
        my $message = $2;
        my $nach_string = $3;
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
          if ( defined $messages{ $message } )
          {
            $my_id = $messages{ $message };
          }
          else
          {
            $message_id ++;
            $my_id = $message_id;
            $messages{ $message } = $my_id;
          }
          $line = "";
          $line .= $davor . "$package.t( \"$message\", $my_id$nach_string$danach";
        }
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
