using Testlib;
using DMLogger;

public class TestDMLogger
{
  public static int main( string[] args )
  {

    GLib.Test.init( ref args );
    GLib.TestSuite ts_dm_logger = new GLib.TestSuite( "DMLogger" );
    GLib.TestSuite.get_root( ).add_suite( ts_dm_logger );


    /* Entry_Bin */
    GLib.TestSuite ts_dm_logger_entry_bin = new GLib.TestSuite( "entry_bin" );
    ts_dm_logger_entry_bin.add(
      new GLib.TestCase(
        "test_f_dm_logger_s_threaded_entry_bin",
        TestDMLogger.default_setup,
        TestDMLogger.test_dm_logger_s_threaded_entry_bin,
        TestDMLogger.default_teardown
      )
    );

    ts_dm_logger_entry_bin.add(
      new GLib.TestCase(
        "test_dm_logger_f_create_log_entry_bin_for_thread",
        TestDMLogger.default_setup,
        TestDMLogger.test_dm_logger_f_create_log_entry_bin_for_thread,
        TestDMLogger.default_teardown
      )
    );

    ts_dm_logger.add_suite( ts_dm_logger_entry_bin );

    GLib.Test.run( );
    return 0;

  }

  public static void default_setup( )
  {    
    Testlib.default_setup( );

  }

  public static void default_teardown( )
  {
    Testlib.default_teardown( );
  }


  /**
   * This method tests if the entry_bin is filled if the logger is started not threaded.
   */
  public static void test_dm_logger_s_threaded_entry_bin( )
  {
    DMLogger.Logger logger = LoggerFactory.get_logger( );

    logger.start_not_threaded( );
    OpenDMLib.DMArray<DMLogger.LogEntry> entry_bin = new OpenDMLib.DMArray<DMLogger.LogEntry>( );
    logger.entry_bin = entry_bin;

    logger.error( "", "", 0, "", 0, false, 0 );

    GLib.assert( entry_bin.length == 1 );
    GLib.assert( entry_bin[ 0 ].type == DMLogger.LOG_ENTRY_ERROR );
  }

  /**
   * This method tests if the create_log_entry_bin_for_thread works.
   */
  public static void test_dm_logger_f_create_log_entry_bin_for_thread( )
  {
    DMLogger.Logger logger = LoggerFactory.get_logger( );

    logger.start_threaded( );
    OpenDMLib.DMArray<DMLogger.LogEntry> entry_bin = new OpenDMLib.DMArray<DMLogger.LogEntry>( );
    logger.entry_bin = entry_bin;
    logger.create_log_entry_bin_for_thread( OpenDMLib.gettid( ) );

    logger.error( "", "", 0, "", 0, false, 0 );
    logger.error( "", "", 0, "", 0, false, 0 );

    uint64 thread_id = 0;
    Thread<void*> t = new Thread<void*>( "Logger Test", ( ) => {
      thread_id = OpenDMLib.gettid( );
      logger.create_log_entry_bin_for_thread( OpenDMLib.gettid( ) );
      logger.error( "", "", 0, "", 0, false, 0 );
      
      return null;
    } );
    t.join( );
    logger.stop( );
    GLib.assert( logger.tid_entry_bin.get( OpenDMLib.gettid( ) ).length == 3 );
    GLib.assert( logger.tid_entry_bin.get( thread_id ).length == 1 );
  }
}

/**
 * The LoggerFactory namespace contains methods which can be used to create logger objects.
 */
namespace LoggerFactory
{
  /**
   * This method creates a logger object.
   * @return A logger object.
   */
  public static DMLogger.Logger get_logger( )
  {
    string logfile = OpenDMLib.get_temp_file( ) + ".log";
    DMLogger.Logger logger = new DMLogger.Logger( logfile );
    Testlib.add_temp_file( logfile );

    return logger;
  }
}

