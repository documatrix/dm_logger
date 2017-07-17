/* *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
 *                            Copyright: Documatrix GmbH
 *                          Source Info: dm_logreader.vala
 *                              Projekt: Allgemein
 *          Version(Versionsverwaltung): 0.1
 *                          Last Update: 2010-05-14 17:35:00
 *                        Last Compiled: 0000-00-00 00:00:00
 *                              Version: 0.1
 *                               Update: 000
 *                                 Info: Verwendet die dm_logger Library um Log-Meldungen aus einem Log-File zu ziehen...
 *                             Compiled: 0000-00-00 00:00:00
 * *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
 */


using OpenDMLib;
using DMLogger;

public const string product_name = "dm_logreader";
public const string product_version = "1.0";

/*
 * Wichtige Variablen für das Parsen der Command-Line
 */
static bool print_version = false;
static bool print_verbose = false;
static string log_file = null;
static string mdb_file = null;
/*
 * Dieses Flag wird verwendet um Filename und Linenumber ins log zu schreiben
 */
static bool debug_mode = false;

const OptionEntry[] entries = {
  { "mdbfile", 'm', 0, OptionArg.STRING, ref mdb_file, "Filename of the Message-Database-File", "Message-Database-File" },
  { "version", 'v', 0, OptionArg.NONE, ref print_version, "Print Version", null },
  { "verbose", 'V', 0, OptionArg.NONE, ref print_verbose, "Print Verbose output", null },
  { "logfile", 'L', 0, OptionArg.STRING, ref log_file, "Filename of the Log-File", "Log-File" },
  { "debug", 'D', 0, OptionArg.NONE, ref debug_mode, "Turn on the debug flag (default off)", null },
  { null }
};

/*
 * Einstiegspunkt
 */
public int main( string[] args )
{
  /*
   * Lesen der Command-Line Parameter
   */
  try
  {
    OptionContext context = new OptionContext( "- " + product_name + " Version " + product_version );
    context.set_help_enabled( true );
    context.add_main_entries( entries, "test" );
    context.parse( ref args );

    if ( print_version == true )
    {
      stdout.printf( "%s, Version %s\n", product_name, product_version );
      return 0;
    }
  }
  catch ( Error e )
  {
    critical( "Error while parsing Options: " + e.message );
    return 1;
  }

  if ( log_file == null )
  {
    critical( "No log-file given!" );
  }
  if ( mdb_file == null )
  {
    critical( "No mdb-file given!" );
  }

  debug( "Starting %s, Version %s\n", product_name, product_version );
  DMLogger.LogReader lr = new DMLogger.LogReader( log_file );

  /* MDB lesen */
  HashTable<string,HashTable<int64?,string>?>? mdb = DMLogger.read_mdb( mdb_file, print_verbose );
  HashTable<int64?,string>? files = new HashTable<int64?,string>( int_hash, int_equal );

  while( true )
  {
    LogEntry le = lr.next_entry( );
    if ( le == null )
    {
      message( "EOF reached" );
      break;
    }
    le.print_out( stdout, files, mdb, print_verbose, debug_mode );

  }
  debug( "Terminating %s, Version %s", product_name, product_version );
  return 0;
}
