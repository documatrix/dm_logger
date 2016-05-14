using OpenDMLib;

namespace DMLogger
{
  public AsyncQueue<LogEntry> log_queue;

  public static const uint16 LOG_ENTRY_RECORD_TYPE_FILEINFO = 1;
  public static const uint16 LOG_ENTRY_RECORD_TYPE_MESSAGE = 2;
  public static const uint16 LOG_ENTRY_RECORD_TYPE_EOF = 4;

  public static const uint16 LOG_ENTRY_NONE = 0;
  public static const uint16 LOG_ENTRY_DEBUG = 1;
  public static const uint16 LOG_ENTRY_INFO = 2;
  public static const uint16 LOG_ENTRY_WARNING = 3;
  public static const uint16 LOG_ENTRY_ERROR = 4;
  public static const uint16 LOG_ENTRY_FATAL = 5;

  /**
   * counts the log
   */
  private int64 log_counter = 0;

  /**
   * The maximum log-count.
   * If this is -1, there is no limit.
   */
  private int64 max_log_count = -1;

  public static Logger log;

  /* Ab diesem Trace-Level soll geloggt werden */
  public int log_trace_level = 0;

  /**
   * This method can be used to read an mdb file which uses the components and message ids.
   * @param mdb_file The filename which should be read.
   * @param print_verbose This flag specifies if the reading process should generate some log messages...
   * @return A hashtable with the components as keys and another hashtable ( with message ids as keys and texts as values ) as value, or null if the mdb could not be read successfully.
   */
  public static HashTable<string,HashTable<int64?,string>?>? read_mdb( string? mdb_file, bool print_verbose = false )
  {
    if ( mdb_file == null )
    {
      stderr.printf( "No MDB-File specified!\n" );
      return null;
    }

    DMFileStream min;
    try
    {
      min = OpenDMLib.IO.open( (!)mdb_file, "rb" );
    }
    catch ( OpenDMLib.IO.OpenDMLibIOErrors e )
    {
      stderr.printf( "Error while opening mdb-File %s! %s\n", (!)mdb_file, e.message );
      return null;
    }

    HashTable<string,HashTable<int64?,string>?>? mdb = new HashTable<string,HashTable<int64?,string>?>( str_hash, str_equal );
    HashTable<int64?,string>? mdb_mini;

    while ( true )
    {
      string? line = min.read_line( );
      if ( line == null )
      {
        if ( print_verbose )
        {
          stdout.printf( "EOF of mdb reached\n" );
        }
        break;
      }

      string[] tokens = ( (!)line ).split( "\x01" );
      if ( print_verbose == true )
      {
        stdout.printf( "Adding %s %lld = %s to mdb...\n", tokens[ 0 ], int64.parse( tokens[ 1 ] ), tokens[ 2 ] );
      }

      if ( mdb.lookup( tokens[ 0 ] ) != null )
      {
        mdb[ tokens[ 0 ] ].insert( int64.parse(tokens[ 1 ] ), tokens[ 2 ] );
      }
      else
      {
        mdb_mini = new HashTable<int64?,string>( int64_hash, int64_equal );
        mdb_mini.insert( int64.parse( tokens[ 1 ] ), tokens[ 2 ] );
        mdb.insert( tokens[ 0 ], mdb_mini );
      }
    }

    return mdb;
  }

  /**
   * This method can be used to read an mdb file which uses caption names instead of message ids.
   * @param mdb_file A filename which should be read.
   * @param print_verbose This flag specifies if the reading process should generate some log messages...
   * @return A hashtable with the components as keys and another hashtable ( with captions as keys and texts as values ) as value, or null if the mdb could not be read successfully.
   */
  public static HashTable<string,HashTable<string?,string>?>? read_caption_mdb( string? mdb_file, bool print_verbose = false )
  {
    if ( mdb_file == null )
    {
      stderr.printf( "No MDB-File specified!\n" );
      return null;
    }
    DMFileStream min;
    try
    {
      min = OpenDMLib.IO.open( (!)mdb_file, "rb" );
    }
    catch ( OpenDMLib.IO.OpenDMLibIOErrors e )
    {
      stderr.printf( "Error while opening mdb-File %s! %s\n", (!)mdb_file, e.message );
      return null;
    }

    HashTable<string?,string>? mdb_mini = null;
    HashTable<string,HashTable<string?,string>?>? mdb = new HashTable<string,HashTable<string?,string>?>( str_hash, str_equal );

    while ( true )
    {
      string? line = min.read_line( );
      if ( line == null )
      {
        if ( print_verbose )
        {
          stdout.printf( "EOF of mdb reached\n" );
        }
        break;
      }

      string[] tokens = ( (!)line ).split( "\x01" );
      if ( print_verbose == true )
      {
        stdout.printf( "Adding %s %s = %s to mdb...\n", tokens[ 0 ], tokens[ 1 ], tokens[ 2 ] );
      }

      if ( mdb.lookup( tokens[ 0 ] ) != null )
      {
        mdb[ tokens[ 0 ] ].insert( tokens[ 1 ], tokens[ 2 ] );
      }
      else
      {
        mdb_mini = new HashTable<string?,string>( str_hash, str_equal );
        mdb_mini.insert( tokens[ 1 ], tokens[ 2 ] );
        mdb.insert( tokens[ 0 ], mdb_mini );
      }
    }
    return mdb;
  }

  public class LogEntry : GLib.Object
  {
    public uint64 tid;
    public uint16 pid;
    public int64 message_id;
    /* Gibt die aktuelle Komponente an */
    public string component;
    public bool exit_entry;
    public bool concat;
    public int64 tstamp;
    public uint16 record_type;
    public string[] parameters;
    public int64 file_id;
    /* Dient für die "Einfärbung" der Log-Messages, z. B. ERROR = rot, ... */
    public uint16 type;
    /* Dient zur Abstufung der Log-Meldungen nach Trace-Level (z. B. 50) */
    public uint16 trace_level;
    public uint16 line;

    /**
     * The LogEntry construktor
     * @param message_id The ID of the LogEntry.
     * @param component The component who created the LogEntry.
     * @param file_id This flag specifies the file_id.
     * @param type This flag specifies the coloring of the LogEntry.
     * @param line The line in which the error occured.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     */
    public LogEntry( int64 message_id, string component, int64 file_id, uint16 type, uint16 line, uint16 trace_level, bool concat )
    {
      this.exit_entry = false;
      this.tid = OpenDMLib.gettid( );
      this.pid = (uint16)OpenDMLib.getpid( );
      this.message_id = message_id;
      this.record_type = LOG_ENTRY_RECORD_TYPE_MESSAGE;
      this.file_id = file_id;
      this.type = type;
      this.line = line;
      this.trace_level = trace_level;
      this.concat = concat;
      this.component = component;

      #if GLIB_2_28
        this.tstamp = GLib.get_real_time( );
      #else
        TimeVal tim = TimeVal( );
        tim.get_current_time( );
        this.tstamp = (int64)( tim.tv_usec + ( tim.tv_sec * 1000000 ) );
      #endif
      this.parameters = {};
    }

    /**
     * The LogEntry file_info construktor
     * @param filename The ID of the LogEntry.
     * @param component The component who created the LogEntry.
     * @param git_version The git Version.
     * @param file_id This flag specifies the file_id.
     * @param line The line in which the error occured.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     */
    public LogEntry.file_info( string filename, string component, string git_version, int64 file_id, uint16 line, uint16 trace_level, bool concat )
    {
      this( 0, component, file_id, LOG_ENTRY_NONE, line, trace_level, concat );
      this.record_type = LOG_ENTRY_RECORD_TYPE_FILEINFO;
      parameters = { filename, git_version };
    }

    public string parse_message( string? message, string[] params )
    {
      StringBuilder new_message = new StringBuilder( );

      for ( int i = 0; i < message.char_count(); i++ )
      {
        if ( message.get_char( message.index_of_nth_char( i ) ) == '$' && ( i + 3 <= message.char_count( ) - 1) )
        {
          if ( message.get_char( message.index_of_nth_char( i + 1 ) ) == '{' )
          {
            int j = 1;
            bool done = false;
            StringBuilder cont = new StringBuilder( );
            while ( true )
            {
              j ++;
              if ( i + j == message.char_count( ) )
              {
                break;
              }
              else if ( message.get_char( message.index_of_nth_char( i + j) ) == '}' )
              {
                done = true;
                i = i + j;
                break;
              }
              else
              {
                cont.append_unichar( message.get_char( message.index_of_nth_char( i + j ) ) );
              }
            }
            if ( done == true )
            {
              if ( int.parse( cont.str ) - 1 >= parameters.length )
              {
                stderr.printf( "Parameter %d referenced, but there are only %d parameters!\n", int.parse( cont.str ), parameters.length );
                stderr.printf( "Message: %s\n", message );
              }
              else
              {
                new_message.append( parameters[ int.parse( cont.str ) - 1 ] );
              }
            }
          }
          else
          {
            new_message.append_unichar( message.get_char( message.index_of_nth_char( i ) ) );
          }
        }
        else
        {
          new_message.append_unichar( message.get_char( message.index_of_nth_char( i ) ) );
        }
      }
      return new_message.str;
    }

    /**
     * This method can be used to read an mdb file which uses caption names instead of message ids.
     * @param files A hashtable with file ids as keys and file names as values
     * @param _mdb A hashtable with the components as keys and another hashtable ( with message ids as keys and texts as values ) as value.
     * @param print_verbose Sets if the output should be verbose.
     * @param debug_mode Sets if the filename and line number should be printed
     */
    public void print_out( HashTable<int64?,string?>files, HashTable<string,HashTable<int64?,string>?>? _mdb, bool print_verbose, bool debug_mode )
    {
      unowned HashTable<int64?,string>? mdb = _mdb.lookup( this.component );

      char ESC = 27;
      if ( print_verbose == true )
      {
        stdout.printf( "\nLog-Entry\n" );
        stdout.printf( "\tProcess-ID: %d\n", this.pid );
        stdout.printf( "\tThread-ID: %lld\n", this.tid );
        stdout.printf( "\tTimestamp: %lld\n", this.tstamp );
        stdout.printf( "\tRecord-Type: %d\n", this.record_type );
        stdout.printf( "\tFile-ID: %g\n", this.file_id );
        stdout.printf( "\tLine: %d\n", this.line );
        stdout.printf( "\tType: %d\n", this.type );
        stdout.printf( "\tComponent: %s\n", this.component );
        if ( this.concat == true )
        {
          stdout.printf( "\tConcat: true\n" );
        }
        else
        {
          stdout.printf( "\tConcat: false\n" );
        }
        stdout.printf( "\tTrace-Level: %d\n", this.trace_level );
        if ( this.record_type == LOG_ENTRY_RECORD_TYPE_FILEINFO )
        {
          stdout.printf( "=== FILEDEF ===\n" );
          stdout.printf( "\tFilename: %s\n", this.parameters[ 0 ] );
          stdout.printf( "\tGit-Version: %s\n", this.parameters[ 1 ] );
        }
        else
        {
          stdout.printf( "\tMessage-ID: %g\n", this.message_id );
          if ( mdb != null && mdb.lookup( this.message_id ) != null )
          {
            string? message = mdb.lookup( this.message_id );
            if ( message == null )
            {
              stderr.printf( "\tMessage for Message-ID %g could not be found!\n", this.message_id );
            }
            else
            {
              stdout.printf( "\tMessage: %s\n", message );
              stdout.printf( "\tMessage Parsed: %s\n", this.parse_message( message, parameters ) );
            }
          }
          else if ( mdb == null )
          {
            stdout.printf( "\tMessage: %g\n", this.message_id );
          }
          else if ( this.message_id != 0 )
          {
            stdout.printf( "=== THIS MESSAGE WAS NOT DEFINED IN THE MESSAGE DATABASE! ===\n" );
          }
          stdout.printf( "\tParameters:\n" );
          foreach ( string p in this.parameters )
          {
            stdout.printf( "\t\t%s\n", p );
          }
        }
      }
      else
      {
        if ( this.record_type == LOG_ENTRY_RECORD_TYPE_MESSAGE )
        {
          if ( this.type == LOG_ENTRY_ERROR )
          {
            stdout.printf( "%c[1;31mERROR ", ESC );
          }
          else if ( this.type == LOG_ENTRY_WARNING )
          {
            stdout.printf( "%c[1mWARNING ", ESC );
          }
          else if ( this.type == LOG_ENTRY_FATAL )
          {
            stdout.printf( "%c[1;31mFATAL ", ESC );
          }
          if ( this.type == LOG_ENTRY_DEBUG )
          {
            stdout.printf( "DEBUG " );
          }
          else if ( this.type == LOG_ENTRY_INFO )
          {
            stdout.printf( "INFO " );
          }

          DMDateTime dt = new DMDateTime.from_unix_local( (int64)( this.tstamp / (int64)1000000 ) );
          stdout.printf( "[%s.%06lld] ", dt.format( "%F %H:%M:%S" ), (int64)( this.tstamp % (int64)1000000 ) );

          if ( debug_mode == true )
          {
            unowned string? _filename;
            string? filename = null;
            if ( ( _filename = files.lookup( this.file_id ) ) == null )
            {
              filename = "<unknown file - file-id: " + this.file_id.to_string( ) + ">";
            }
            else
            {
              filename = _filename;
            }
            stdout.printf( "(%s:%u) ", filename, this.line );
          }

          unowned string? message = mdb.lookup( this.message_id );
          if ( message == null )
          {
            stderr.printf( "\tMessage for Message-ID %g could not be found!\n", this.message_id );
          }
          else
          {
            stdout.printf( "%s", this.parse_message( message, parameters ) );
          }
          if ( this.type == LOG_ENTRY_ERROR || this.type == LOG_ENTRY_WARNING || this.type == LOG_ENTRY_FATAL )
          {
            stdout.printf( "%c[0m",ESC );
          }
          stdout.printf( "\n" );
        }
        else if ( this.record_type == LOG_ENTRY_RECORD_TYPE_FILEINFO )
        {
          files.insert( this.file_id, this.parameters[ 0 ] );
        }
      }
    }

    /**
     * This method will write the log entry to the given @see OpenDMLib.IO.BufferedFile.
     * @param log_writer The file to which this entry should be written.
     */
    public void out_file( OpenDMLib.IO.BufferedFile log_writer ) throws Error
    {
      if ( this.exit_entry )
      {
        this.record_type = LOG_ENTRY_RECORD_TYPE_EOF;
        log_writer.add_to_buffer( &this.record_type, sizeof( uint16 ) );
        return;
      }
      log_writer.add_to_buffer( &this.record_type, sizeof( uint16 ) );
      log_writer.add_to_buffer( &this.pid, sizeof( uint16 ) );
      log_writer.add_to_buffer( &this.tid, sizeof( uint64 ) );
      log_writer.add_to_buffer( &this.tstamp, sizeof( int64 ) );
      log_writer.add_to_buffer( &this.file_id, sizeof( int64 ) );
      log_writer.add_to_buffer( &this.line, sizeof( uint16 ) );
      log_writer.add_to_buffer( &this.type, sizeof( uint16 ) );
      if ( this.concat == true )
      {
        uint8 tmp = 1;
        log_writer.add_to_buffer( &tmp, sizeof( uint8 ) );
      }
      else
      {
        uint8 tmp = 0;
        log_writer.add_to_buffer( &tmp, sizeof( uint8 ) );
      }
      log_writer.add_to_buffer( &this.trace_level, sizeof( uint16 ) );
      log_writer.add_to_buffer( &this.message_id, sizeof( int64 ) );

      log_writer.write_string( this.component );

      int16 tmp = (int16)this.parameters.length;
      log_writer.add_to_buffer( &tmp, sizeof( int16 ) );
      for ( int i = 0; i < this.parameters.length; i++ )
      {
        log_writer.write_string( this.parameters[ i ] );
      }
    }
  }

  /**
   * This method can be used to translate a log message using the message database to a language.
   * @param caption_name The name of the caption.
   * @param fallback If no message database is loaded then this fallback message is used.
   * @param ... A list of strings which will be used to replace the ${...} patterns.
   * @return The translated message.
   */
  public string t( string caption_name, string fallback, ... )
  {
    string message = fallback;

    /* Check if a message database is loaded and then get the message from the mdb... */
    if ( DMLogger.log != null && DMLogger.log.mdb != null )
    {
      foreach( string? s in DMLogger.log.caption_mdb.get_keys( ) )
      {
        unowned string? mdb_message = s;
        if ( mdb_message != null )
        {
          message = (!)mdb_message;
        }
      }
    }

    /* Replace the ${...} patterns using the given list of arguments. */
    va_list l = va_list( );
    string[] tmp = { };
    string? v;
    while ( true )
    {
      v = l.arg( );
      if ( v == null )
      {
        break;
      }
      tmp += v;
    }

    uint16 char_index = 0;
    uint16 char_count = (uint16)message.char_count( );
    int index = 0;
    unichar c;

    uint8 NO_STATE = 0;
    uint8 PATTERN_START = 1;
    uint8 PATTERN = 2;
    uint8 state = NO_STATE;

    uint16 pattern_pos = 0;

    StringBuilder final_message = new StringBuilder.sized( message.length );
    while ( message.get_next_char( ref index, out c ) )
    {
      if ( state == NO_STATE )
      {
        /* Normal text */
        if ( c == '$' && char_index + 3 < char_count )
        {
          /* This could be the start of a pattern... */
          state = PATTERN_START;
          pattern_pos = 0;
        }
        else
        {
          /* Normal character */
          final_message.append_unichar( c );
        }
      }
      else if ( state == PATTERN_START )
      {
        if ( c == '{' )
        {
          /* Now the pattern really starts... */
          state = PATTERN;
        }
        else
        {
          /* Invalid character! */
          state = NO_STATE;
          stderr.printf( "Error parsing message \"%s\" at character %u! Illegal pattern-start character '%s'!\n", message, char_index + 1, c.to_string( ) );
          final_message.append_unichar( '$' );
          final_message.append_unichar( c );
        }
      }
      else
      {
        /* In pattern... */
        if ( c >= '0' && c <= '9' )
        {
          pattern_pos *= 10;
          pattern_pos += (uint16)( c - '0' );
        }
        else if ( c == '}' )
        {
          /* End of pattern */
          state = NO_STATE;

          pattern_pos --;
          if ( pattern_pos >= 0 && pattern_pos < tmp.length )
          {
            final_message.append( tmp[ pattern_pos ] );
          }
          else
          {
            stderr.printf( "Error parsing message \"%s\"! Tried to access parameter %d but this parameter is not defined!\n", message, pattern_pos + 1 );
          }
        }
        else
        {
          /* Illegal character in pattern! */
          stderr.printf( "Error parsing message \"%s\" at character %u! Illegal pattern character '%s'!\n", message, char_index + 1, c.to_string( ) );
        }
      }
      char_index ++;
    }

    return final_message.str;
  }

  public class Logger : GLib.Object
  {
#if GLIB_2_32
    private Thread<void*> running;
#else
    private unowned Thread<void*> running;
#endif
    string logfile;
    int64 __last_file_id__;
    HashTable<string,int64?> logged_files;

    /**
     * Sets if the filename and line sould be printed
     */
    public bool debug_mode;

    public bool log_to_console;
    public string? mdb_file;

    /**
     * This hashtable will be filled by the read_mdb method and
     * contains the component and another hastable filled with
     * the messages (with message ids names as keys).
     */
    public HashTable<string,HashTable<int64?,string>?>? mdb = null;

    /**
     * This hashtable contains the filenames of the files which
     * already did a log output.
     * The key is a auto-generated file id and is used when printing the log message
     * to the log-file.
     */
    public HashTable<int64?,string>? files;

   /**
    * Sets if the Logger is threaded.
    */
    public bool threaded = true;

    /**
     * This hashtable will be filled by the read_caption_mdb method and
     * contains the messages with caption names as keys.
     */
    public HashTable<string,HashTable<string?,string>?>? caption_mdb = null;

    /* Ein Array das mit Log-Entries befüllt wird, wenn es "von außen" gesetzt wird. */
    public DMArray<LogEntry>? entry_bin = null;

    public OpenDMLib.IO.BufferedFile? log_writer = null;

    /**
     * This hash table will contain the log entries for certain Threads.
     */
    public HashTable<uint64?,DMArray<LogEntry>?>? tid_entry_bin = null;

    /**
     * Adds a new Thread-ID to the tid_entry_bin hash table.
     * @param tid the ID of the Thread
     */
    public void create_log_entry_bin_for_thread( uint64 tid )
    {
      if ( this.tid_entry_bin == null )
      {
        this.tid_entry_bin = new HashTable<uint64?,DMArray<LogEntry>?>( OpenDMLib.uint64_hash, OpenDMLib.uint64_equal );
      }
      OpenDMLib.DMArray<DMLogger.LogEntry> log_messages = new OpenDMLib.DMArray<DMLogger.LogEntry>( );
      this.tid_entry_bin.insert( tid, log_messages );
    }

    /*
     * Führt Logging Aktivitäten aus
     */
    public void* run( )
    {
      while( true )
      {
        LogEntry? e = DMLogger.log_queue.pop( );
        if ( e == null )
        {
          break;
        }
        try
        {
          if ( this.log_writer != null )
          {
            e.out_file( (!)this.log_writer );
          }
          if ( e == null || e.exit_entry == true )
          {
            if ( this.log_writer != null )
            {
              ( (!)this.log_writer ).write_out_buffer( );
            }
            break;
          }
          if ( log_to_console )
          {
            e.print_out( this.files, this.mdb, false, this.debug_mode );
          }
          if ( this.tid_entry_bin != null && this.tid_entry_bin.get( e.tid ) != null )
          {
            this.tid_entry_bin.get( e.tid ).push( e );
          }
          if ( this.entry_bin != null )
          {
            this.entry_bin.push( e );
          }
        }
        catch ( Error e )
        {
          GLib.critical( "Error while logging message: " + e.message );
        }
      }
      //Thread.self().exit(null);
      return null;
    }

    /**
     * Logger will be started in an new thread
     */
    public void start_threaded( )
    {
      #if GLIB_2_32
        this.running = new Thread<void*>( "Logger", this.run );
      #else
        try
        {
          this.running = Thread.create<void*>( this.run, true );
        }
        catch ( ThreadError e )
        {
          stdout.printf( "Error while creating thread for logger: %s\n", e.message );
        }
      #endif
    }

    /**
     * Logger won't be started in a new thread
     */
    public void start_not_threaded( )
    {
      this.threaded = false;
    }

    /**
     * A new debug LogEntry will be created.
     * @param component The current component.
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param ... A list of strings which will be used to replace the ${...} patterns.
     */
    public void debug( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_DEBUG, trace_level, concat, message_id, component, false, l );
    }

    /**
     * A new info LogEntry will be created.
     * @param component The current component.
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param ... A list of strings which will be used to replace the ${...} patterns.
     */
    public void info( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_INFO, trace_level, concat, message_id, component, false, l );
    }

    /**
     * A new warning LogEntry will be created.
     * @param component The current component.
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param ... A list of strings which will be used to replace the ${...} patterns.
     */
    public void warning( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_WARNING, trace_level, concat, message_id, component, false, l );
    }

    /**
     * A new error LogEntry will be created.
     * @param component The current component.
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param ... A list of strings which will be used to replace the ${...} patterns.
     */
    public void error( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_ERROR, trace_level, concat, message_id, component, false, l );
    }

    /**
     * A new error LogEntry will be created.
     * @param component The current component.
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param ... A list of strings which will be used to replace the ${...} patterns.
     */
    public void fatal( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_FATAL, trace_level, concat, message_id, component, true, l );
    }

    /**
     * Creates a new LogEntry
     * @param filename The ID of the LogEntry.
     * @param line_number The line in which the error occured.
     * @param git_version The git Version.
     * @param type This flag specifies the coloring of the LogEntry.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @param concat Specifies if the LogEntriy is concatenated.
     * @param message_id This flag specifies the message_id.
     * @param component The current component.
     * @param force_log If this is true the log get logged no matter what the log-count is.
     * @param va_list args A list of strings params.
     */
    private void __generate_message__( string filename, uint16 line_number, string git_version, uint16 type, uint16 trace_level, bool concat, int64 message_id, string component, bool force_log, va_list args )
    {
      int64 file_id = this.__handle_file__( filename, component, git_version, line_number, trace_level );
      LogEntry e = new LogEntry( message_id, component, file_id, type, line_number, trace_level, concat );
      string[] tmp = {};
      string? v;
      while ( true )
      {
        v = args.arg<string?>( );
        if ( v == null )
        {
          break;
        }
        tmp += (!)v;
      }
      e.parameters = tmp;

      if ( this.threaded )
      {
        DMLogger.log_queue.push( e );
      }
      else
      {
        try
        {
          if ( this.log_writer != null )
          {
            e.out_file( (!)this.log_writer );
          }
          if ( log_to_console && this.should_make_log( force_log ) )
          {
            e.print_out( this.files, this.mdb, false, this.debug_mode );
          }
          if ( this.tid_entry_bin != null && this.tid_entry_bin.get( e.tid ) != null && this.should_make_log( force_log ) )
          {
            this.tid_entry_bin.get( e.tid ).push( e );
          }
          if ( this.entry_bin != null && this.should_make_log( force_log ) )
          {
            this.entry_bin.push( e );
          }
        }
        catch ( Error err )
        {
          stderr.printf( "Error while logging message: %s\n", err.message );
        }
      }
      log_counter ++;
    }

    /**
     * This method resets the log_count
     */
    public void reset_log_count( )
    {
      log_counter = 0;
    }

    /**
     * This method sets the max_log_count
     * @param max_log_count The max_log_count.
     */
    public void set_max_log_count( int64 log_count )
    {
      max_log_count = log_count;
    }

    /**
     * This method returns if the log-count is ok to log
     * @param force_log If this is true the return-value is true.
     * @return if the log-count is ok to log true else false.
     */
    public bool should_make_log( bool force_log )
    {
      return force_log || log_counter < max_log_count || max_log_count == -1;
    }

    /**
     * This method gives you the file_id and generates the file_info message if it is the first LogEntry
     * @param filename The ID of the LogEntry.
     * @param component The current component.
     * @param git_version The git Version.
     * @param line_number The line in which the error occured.
     * @param trace_level Every LogEntry with a lower trace_level than the given one will be printed.
     * @return The file_id.
     */
    private int64 __handle_file__( string filename, string component, string git_version, uint16 line_number, uint16 trace_level )
    {
      int64? file_id = this.logged_files.lookup( filename );
      if ( file_id == null )
      {
        /* Dieses File bringt zum ersten mal eine Log-Meldung => File-Info Message mit GIT-Version generieren */
        this.__last_file_id__ ++;
        file_id = this.__last_file_id__;
        LogEntry fi = new LogEntry.file_info( filename, component, git_version, file_id, line_number, trace_level, false );
        if ( this.threaded )
        {
          DMLogger.log_queue.push( fi );
        }
        else
        {
          try
          {
            if ( this.log_writer != null )
            {
              fi.out_file( (!)this.log_writer );
            }
            if ( log_to_console )
            {
              fi.print_out( this.files, this.mdb, false, this.debug_mode );
            }
          }
          catch ( Error e )
          {
            GLib.critical( "Error while logging message: " + e.message );
          }
        }
        this.logged_files.insert( filename, file_id );
      }
      return (int64)file_id;
    }

    /**
     * Stops the Logger
     */
    public void stop( )
    {
      if ( this.threaded )
      {
        LogEntry e = new LogEntry( 0, "", 0, LOG_ENTRY_NONE, 0, 0, false );
        e.exit_entry = true;
        DMLogger.log_queue.push( e );
        if ( this.running != null )
        {
          this.running.join( );
        }
      }
      else
      {
        if ( this.log_writer != null )
        {
          ( (!)this.log_writer ).write_out_buffer( );
        }
      }
    }

    /**
     * The Logger's constructor
     * @param logfile The path of the logfile.
     */
    public Logger( string? logfile )
    {
      DMLogger.log_queue = new AsyncQueue<LogEntry>( );
      this.logfile = logfile;
      if ( logfile != null )
      {
        try
        {
          this.log_writer = new IO.BufferedFile.with_filename( logfile );
        }
        catch ( OpenDMLib.IO.OpenDMLibIOErrors e )
        {
          stderr.printf( "Could not open specified log file \"%s\" for writing! %s\n", logfile, e.message );
        }
      }
      else
      {
        this.log_writer = null;
      }

      this.logged_files = new HashTable<string, int16?>( str_hash, str_equal );
      this.__last_file_id__ = -1;
      this.log_to_console = false;
    }

    /**
     * Sets Logger config
     * @param log_to_console Sets if the Logger should print the messages on the console.
     * @param mdb_file The path of the mdb file.
     */
    public void set_config( bool log_to_console, string? mdb_file, bool debug_mode = false )
    {
      if ( log_to_console )
      {
        if ( this.mdb == null )
        {
          this.mdb_file = mdb_file;
          this.mdb = DMLogger.read_mdb( mdb_file, false );
        }
        if ( this.caption_mdb == null )
        {
          this.caption_mdb = DMLogger.read_caption_mdb( mdb_file, false );
        }
        if ( this.mdb == null || this.caption_mdb == null )
        {
          stderr.printf( "Could not initialize logger correctly! MDB-File %s could not be read!\n", this.mdb_file );
          return;
        }
        this.files = new HashTable<int16?,string>( int_hash, int_equal );
        this.log_to_console = log_to_console;
        this.debug_mode = debug_mode;
      }
    }
  }

  public class LogReader : GLib.Object
  {
    string logfile;

    /**
     * This @see OpenDMLib.IO.BufferedFileReader represents the log file.
     */
    public OpenDMLib.IO.BufferedFileReader log_reader;

    public LogReader( string logfile )
    {
      this.logfile = logfile;
      try
      {
        this.log_reader = new OpenDMLib.IO.BufferedFileReader.with_filename( logfile );
      }
      catch ( OpenDMLib.IO.OpenDMLibIOErrors e )
      {
        stderr.printf( "Could not open Log-File %s for reading! %s\n", logfile, e.message );
      }
    }

    public LogEntry? next_entry( )
    {
      if ( this.log_reader == null )
      {
        GLib.critical( "No Log-File opened!" );
        return null;
      }
      try
      {
        LogEntry e;
        uint16 record_type = 0;
        this.log_reader.get_from_buffer( &record_type, sizeof( uint16 ) );
        if ( record_type == LOG_ENTRY_RECORD_TYPE_EOF )
        {
          stdout.printf( "EOF of logfile reached\n" );
          return null;
        }
        uint16 pid = 0;
        this.log_reader.get_from_buffer( &pid, sizeof( uint16 ) );
        uint64 tid = 0;
        this.log_reader.get_from_buffer( &tid, sizeof( uint64 ) );
        int64 tstamp = 0;
        this.log_reader.get_from_buffer( &tstamp, sizeof( int64 ) );
        int64 file_id = 0;
        this.log_reader.get_from_buffer( &file_id, sizeof( int64 ) );
        uint16 line = 0;
        this.log_reader.get_from_buffer( &line, sizeof( uint16 ) );
        uint16 type = 0;
        this.log_reader.get_from_buffer( &type, sizeof( uint16 ) );
        uint8 concat = 0;
        this.log_reader.get_from_buffer( &concat, sizeof( uint8 ) );
        bool concat_b = false;
        if ( concat == 0 )
        {
          concat_b = false;
        }
        else
        {
          concat_b = true;
        }
        uint16 trace_level = 0;
        this.log_reader.get_from_buffer( &trace_level, sizeof( uint16 ) );
        int64 message_id = 0;
        this.log_reader.get_from_buffer( &message_id, sizeof( int64 ) );

        string component = this.log_reader.read_string( );

        int16 parameter_count = 0;
        this.log_reader.get_from_buffer( &parameter_count, sizeof( int16 ) );
        string[] tmp = new string[ parameter_count ];
        for ( int p = 0; p < parameter_count; p++ )
        {
          tmp[ p ] = this.log_reader.read_string( );
        }
        e = new LogEntry( message_id, component, file_id, type, line, trace_level, concat_b );
        e.parameters = tmp;
        e.pid = pid;
        e.tid = tid;
        e.tstamp = tstamp;
        e.record_type = record_type;
        return e;
      }
      catch ( Error err )
      {
        /* EOF Reached */
        return null;
      }
    }
  }
}
