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

    /* timestamp formatting */
    GLib.TestSuite ts_dm_logger_timestamp = new GLib.TestSuite( "timestamp" );
    ts_dm_logger_timestamp.add(
      new GLib.TestCase(
        "test_f_dm_logger_format_log_timestamp",
        TestDMLogger.default_setup,
        TestDMLogger.test_dm_logger_format_log_timestamp,
        TestDMLogger.default_teardown
      )
    );
    ts_dm_logger.add_suite( ts_dm_logger_timestamp );

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
#if GLIB_2_32
    Thread<void*> t = new Thread<void*>( "Logger Test", ( ) =>
    {
      thread_id = OpenDMLib.gettid( );
      logger.create_log_entry_bin_for_thread( OpenDMLib.gettid( ) );
      logger.error( "", "", 0, "", 0, false, 0 );

      return null;
    } );
#else
    unowned Thread<void*> t;
    try
    {
      t = Thread.create<void*>( ( ) =>
      {
        thread_id = OpenDMLib.gettid( );
        logger.create_log_entry_bin_for_thread( OpenDMLib.gettid( ) );
        logger.error( "", "", 0, "", 0, false, 0 );

        return null;
      }, true );
    }
    catch ( ThreadError e )
    {
      GLib.assert_not_reached( );
    }
#endif
    t.join( );
    logger.stop( );
    GLib.assert( logger.tid_entry_bin.get( OpenDMLib.gettid( ) ).length == 3 );
    GLib.assert( logger.tid_entry_bin.get( thread_id ).length == 1 );
  }

  /**
   * Tests that format_log_timestamp produces the expected
   * "YYYY-MM-DD HH:MM:SS" prefix in the caller-supplied buffer
   * and that calls with the same whole-second value reuse the
   * cached prefix (correctness check: result must still be right).
   *
   * The check is timezone-independent: we feed a known epoch-second
   * value, call format_log_timestamp twice with that same second
   * and once with second+1, and verify all three prefixes are
   * well-formed and that the first two are byte-equal.
   */
  public static void test_dm_logger_format_log_timestamp( )
  {
    char buf_a[20];
    char buf_b[20];
    char buf_c[20];

    /* 1_700_000_000 seconds == 2023-11-14 22:13:20 UTC.
     * Local-time representation depends on TZ, but determinism
     * within one run is all we need. */
    int64 base_ts = (int64)1700000000 * (int64)1000000;   /* microseconds */

    DMLogger.format_log_timestamp( base_ts,                  buf_a );
    DMLogger.format_log_timestamp( base_ts + (int64)500000,  buf_b );  /* same second */
    DMLogger.format_log_timestamp( base_ts + (int64)1500000, buf_c );  /* +1 second */

    string s_a = (string)buf_a;
    string s_b = (string)buf_b;
    string s_c = (string)buf_c;

    /* Well-formedness: "YYYY-MM-DD HH:MM:SS" => 19 chars. */
    GLib.assert( s_a.length == 19 );
    GLib.assert( s_b.length == 19 );
    GLib.assert( s_c.length == 19 );

    /* Layout: digits and separators at fixed positions. */
    GLib.assert( s_a[ 4]  == '-' );
    GLib.assert( s_a[ 7]  == '-' );
    GLib.assert( s_a[10]  == ' ' );
    GLib.assert( s_a[13]  == ':' );
    GLib.assert( s_a[16]  == ':' );

    /* Same whole-second => identical prefix. */
    GLib.assert( s_a == s_b );

    /* +1 second => different prefix (last char differs at minimum). */
    GLib.assert( s_a != s_c );
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

