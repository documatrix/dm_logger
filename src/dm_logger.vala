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

  public static Logger log;

  public static size_t BUFFER_SIZE = 1024 * 4;

  /* Ab diesem Trace-Level soll geloggt werden */
  public int log_trace_level = 0;

  public FileStream? log_writer_fos;
  uchar[] log_buffer;
  size_t log_buffer_index;
  /* Wenn im Buffer noch was steht, wird es hier raus geschrieben */
  public void write_out_log_buffer( )
  {
    if ( log_buffer_index > 0 )
    {
      log_writer_fos.write( log_buffer[ 0:log_buffer_index ] );
      log_buffer_index = 0;
    }
  }
  public void add_to_log_buffer( void * data, size_t size ) throws Error
  {
    try
    {
      if ( log_buffer_index + size > BUFFER_SIZE )
      {
        /* Das geht sich nicht mehr aus! */
        log_writer_fos.write( log_buffer[ 0:log_buffer_index ] );
        log_buffer_index = 0;
      }
      Memory.copy( &log_buffer[ log_buffer_index ], data, size );
      log_buffer_index += size;
    }
    catch (Error e)
    {
      error( "Error writing to logfile: %s", e.message );
    }
  }
  public void write_log_string( string s ) throws Error
  {
    char[] tmp = s.to_utf8( );
    int64 l = tmp.length;
    add_to_log_buffer( &l, sizeof( int64 ) );
    add_to_log_buffer( tmp, (size_t)l );
  }

  public static HashTable<string,HashTable<int64?,string>?>? read_mdb( string? mdb_file, bool print_verbose = false )
  {
    if ( mdb_file == null )
    {
      stderr.printf( "No MDB-File specified!\n" );
      return null;
    }

    FileStream min;
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

    try
    {
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
    }
    catch ( Error e )
    {
      stderr.printf( "An error occured while parsing the message database %s! %s\n", (!)mdb_file, e.message );
    }

    return mdb;
  }

  /**
   * This method can be used to read an mdb file which uses caption names instead of message ids.
   * @param mdb_file A filename which should be read.
   * @param print_verbose This flag specifies if the reading process should generate some log messages...
   * @return A hashtable with captions as keys and texts as values or null if the mdb could not be read successfully.
   */
  public static HashTable<string,HashTable<string?,string>?>? read_caption_mdb( string? mdb_file, bool print_verbose = false )
  {
    if ( mdb_file == null )
    {
      stderr.printf( "No MDB-File specified!\n" );
      return null;
    }
    FileStream min;
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

    try
    {
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
    }
    catch ( Error e )
    {
      stderr.printf( "An error occured while parsing the message database %s! %s\n", (!)mdb_file, e.message );
    }
    return mdb;
  }

  public class LogEntry : GLib.Object
  {
    public uint16 tid;
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
    * params will be added soon
    */
    public LogEntry( int64 message_id, string component, int64 file_id, uint16 type, uint16 line, uint16 trace_level, bool concat )
    {
      this.exit_entry = false;
      this.tid = (uint16)OpenDMLib.gettid( );
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
    * params will be added soon
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

      for (int i = 0; i < message.char_count(); i++)
      {
        if (message.get_char(message.index_of_nth_char(i)) == '$' && (i + 3 <= message.char_count() - 1))
        {
          if (message.get_char(message.index_of_nth_char(i + 1)) == '{')
          {
            int j = 1;
            bool done = false;
            StringBuilder cont = new StringBuilder();
            while (true)
            {
              j ++;
              if (i + j == message.char_count())
              {
                break;
              }
              else if (message.get_char(message.index_of_nth_char(i + j)) == '}')
              {
                done = true;
                i = i + j;
                break;
              }
              else
              {
                cont.append_unichar(message.get_char(message.index_of_nth_char(i + j)));
              }
            }
            if (done == true)
            {
              if (int.parse(cont.str) - 1 >= parameters.length)
              {
                stderr.printf("Parameter %d referenced, but there are only %d parameters!\n", int.parse(cont.str), parameters.length);
                stderr.printf("Message: %s\n", message);
              }
              else
              {
                new_message.append(parameters[int.parse(cont.str) - 1]);
              }
            }
          }
          else
          {
            new_message.append_unichar(message.get_char(message.index_of_nth_char(i)));
          }
        }
        else
        {
          new_message.append_unichar(message.get_char(message.index_of_nth_char(i)));
        }
      }
      return new_message.str;
    }

   /**
    * Valadoc folgt...
    */
    public void print_out( HashTable<int64?,string?>files, HashTable<string,HashTable<int64?,string>?>? _mdb, bool print_verbose = true )
    {
      unowned HashTable<int64?,string>? mdb = _mdb.lookup( this.component );

      char ESC = 27;
      if ( print_verbose == true )
      {
        stdout.printf( "\nLog-Entry\n" );
        stdout.printf( "\tProcess-ID: %d\n", this.pid );
        stdout.printf( "\tThread-ID: %d\n", this.tid );
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
              stdout.printf("\tMessage: %s\n", message);
              stdout.printf("\tMessage Parsed: %s\n", this.parse_message( message, parameters ) );
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
          unowned string? message = mdb.lookup( this.message_id );
          if ( message == null )
          {
            stderr.printf( "\tMessage for Message-ID %g could not be found!\n", this.message_id );
          }
          else
          {
            stdout.printf( "%s", this.parse_message( message, parameters ) );
          }
          if ( this.type == LOG_ENTRY_ERROR || this.type == LOG_ENTRY_WARNING )
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

    /* Aufbau einer Log-Message */
    /* Record-Type (uint16), Process-ID (uint16), Thread-ID (uint16), Timestamp (uint64), File-ID (int), Line (uint16), Type (uint16), Concat (byte), Trace-Level (uint16), Message-ID (uint16), Parameter-Count (int16), Parameter-Größe (int64), Parameter (string mit Größe aus dem vorherigen Feld), ... */
    /* Aufbau einer Log-Message im Falle eines parsed_objects */
    /* Record-Type (uint16), Process-ID (uint16), Thread-ID (uint16), Timestamp (uint64), File-ID (int), Line (uint16), Type (uint16), Concat (byte), Trace-Level (uint16), Größe Name (int64), Name (string mit Größe aus dem vorherigen Feld), Größe Filename (int64), Filename (string), Fileposition (int64), Line (int64), Page (int32), Tagtype (byte), Begin CS (byte), End CS (byte), Parameter-Count (int16), Parameter Größe (int64), Parameter (string), ..., Content Größe (int64), Content (string) */
    public void out_file( ) throws Error
    {
      //critical("outing file");
      if ( this.exit_entry )
      {
        this.record_type = LOG_ENTRY_RECORD_TYPE_EOF;
        add_to_log_buffer( &this.record_type, sizeof( uint16 ) );
        return;
      }
      add_to_log_buffer( &this.record_type, sizeof( uint16 ) );
      add_to_log_buffer( &this.pid, sizeof( uint16 ) );
      add_to_log_buffer( &this.tid, sizeof( uint16 ) );
      add_to_log_buffer( &this.tstamp, sizeof( int64 ) );
      add_to_log_buffer( &this.file_id, sizeof( int64 ) );
      add_to_log_buffer( &this.line, sizeof( uint16 ) );
      add_to_log_buffer( &this.type, sizeof( uint16 ) );
      if (this.concat == true)
      {
        uint8 tmp = 1;
        add_to_log_buffer( &tmp, sizeof( uint8 ) );
      }
      else
      {
        uint8 tmp = 0;
        add_to_log_buffer( &tmp, sizeof( uint8 ) );
      }
      add_to_log_buffer( &this.trace_level, sizeof( uint16 ) );
      add_to_log_buffer( &this.message_id, sizeof( int64 ) );

      write_log_string( this.component );

      int16 tmp = (int16)this.parameters.length;
      add_to_log_buffer( &tmp, sizeof( int16 ) );
      for (int i = 0; i < this.parameters.length; i++)
      {
        write_log_string( this.parameters[ i ] );
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
    public bool log_to_console;
    public string? mdb_file;

    /**
     * This hashtable will be filled by the read_mdb method and
     * contains the component and another hastable filled with
     * the messages (with message ids names as keys).
     */
    public HashTable<string,HashTable<int64?,string>?>? mdb;

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
    public HashTable<string,HashTable<string?,string>?>? caption_mdb;

    /* Ein Array das mit Log-Entries befüllt wird, wenn es "von außen" gesetzt wird. */
    public DMArray<LogEntry>? entry_bin = null;


    /*
     * Führt Logging Aktivitäten aus
     */
    public void* run()
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
          if ( DMLogger.log_writer_fos != null )
          {
            e.out_file( );
          }
          if ( e == null || e.exit_entry == true )
          {
            if ( DMLogger.log_writer_fos != null )
            {
              write_out_log_buffer( );
            }
            break;
          }
          if ( log_to_console )
          {
            e.print_out( this.files, this.mdb, false );
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

    public void start_threaded( )
    {
      try
      {
#if GLIB_2_32
        this.running = new Thread<void*>( "Logger", this.run );
#else
        this.running = Thread.create<void*>( this.run, true );
#endif
      }
      catch (Error e)
      {
        GLib.critical("Error while creating thread for logger: " + e.message);
      }
    }

   /**
    * Valadoc folgt
    */
    public void start_not_threaded( )
    {
      this.threaded = false;
    }

    public void debug( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list( );
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_DEBUG, trace_level, concat, message_id, component, l );
    }

    public void info( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list();
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_INFO, trace_level, concat, message_id, component, l );
    }

    public void warning( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list();
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_WARNING, trace_level, concat, message_id, component, l );
    }

    public void error( string component, string filename, uint16 line_number, string git_version, uint16 trace_level, bool concat, int64 message_id, ... )
    {
      va_list l = va_list();
      this.__generate_message__( filename, line_number, git_version, LOG_ENTRY_ERROR, trace_level, concat, message_id, component, l );
    }


    private void __generate_message__( string filename, uint16 line_number, string git_version, uint16 type, uint16 trace_level, bool concat, int64 message_id, string component, va_list args )
    {
      int64 file_id = this.__handle_file__( filename, component, git_version, line_number, trace_level );
      LogEntry e = new LogEntry( message_id, component, file_id, type, line_number, trace_level, concat );
      string[] tmp = {};
      string? v;
      while ( true )
      {
        v = args.arg( );
        if ( v == null )
        {
          break;
        }
        tmp += v;
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
          e.out_file( );
          if ( log_to_console )
          {
            e.print_out( this.files, this.mdb, false );
          }
          if ( this.entry_bin != null )
          {
            this.entry_bin.push( e );
          }
        }
        catch ( Error err )
        {
          stderr.printf( "Error while logging message: %s\n", err.message );
        }
      }
    }
   /**
    * Valadoc folgt
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
            fi.out_file( );
            if ( log_to_console )
            {
              fi.print_out( this.files, this.mdb, false );
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

    public void stop( )
    {
      try
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
          write_out_log_buffer( );
        }
      }
      catch ( Error e )
      {
        GLib.critical( "Error while stopping logger: " + e.message );
      }
    }

    public Logger( string? logfile )
    {
      DMLogger.log_queue = new AsyncQueue<LogEntry>( );
      this.logfile = logfile;
      if ( logfile != null )
      {
        try
        {
          DMLogger.log_writer_fos = OpenDMLib.IO.open( logfile, "wb" );
        }
        catch ( OpenDMLib.IO.OpenDMLibIOErrors e )
        {
          stderr.printf( "Could not open specified log file \"%s\" for writing! %s\n", logfile, e.message );
        }
      }
      else
      {
        DMLogger.log_writer_fos = null;
      }
      log_buffer = new uchar[ BUFFER_SIZE ];
      log_buffer_index = 0;

      this.logged_files = new HashTable<string, int16?>( str_hash, str_equal );
      this.__last_file_id__ = -1;
      this.log_to_console = false;
    }

    public void set_config( bool log_to_console, string? mdb_file )
    {
      if ( log_to_console )
      {
        this.mdb_file = mdb_file;
        this.mdb = DMLogger.read_mdb( mdb_file, false );
        this.caption_mdb = DMLogger.read_caption_mdb( mdb_file, false );
        if ( this.mdb == null || this.caption_mdb == null )
        {
          stderr.printf( "Could not initialize logger correctly! MDB-File %s could not be read!\n", this.mdb_file );
          return;
        }
        this.files = new HashTable<int16?,string>( int_hash, int_equal );
        this.log_to_console = log_to_console;
      }
    }
  }

  public class LogReader : GLib.Object
  {
    string logfile;
    FileStream? dis;
    /* Diese beiden Buffer-Variablen betreffen den Buffer für das Auslesen aus dem File */
    uchar[] buffer;
    size_t buffer_index;

    public LogReader( string logfile )
    {
      this.logfile = logfile;
      this.dis = OpenDMLib.IO.open( logfile, "rb" );
      if (dis == null)
      {
        GLib.critical( "Could not open Log-File for reading!" );
      }
      this.buffer = new uchar[BUFFER_SIZE];
      this.buffer_index = BUFFER_SIZE;
    }

    public string read_string( ) throws Error
    {
      int64 l = 0;
      this.get_from_buffer(&l, sizeof(int64));
      char[] tmp = new char[l + 1];
      this.get_from_buffer(tmp, (size_t)l);
      tmp[l] = 0;
      return (string)tmp;
    }

    public void get_from_buffer( void * data, size_t size )
    {
      try
      {
        size_t delta = 0;
        uchar[] tmp_buffer = new uchar[size];
        if ( this.buffer_index + size > BUFFER_SIZE )
        {
          /* Das geht sich nicht mehr aus! */
          /* Muss ich stückeln (kommt vor, wenn sich die Daten noch zum Teil im alten Buffer stehen)? */
          delta = BUFFER_SIZE - this.buffer_index;

          if ( delta > 0 && delta < size )
          {
            /* Das Delta ist leider nicht genau die größe => ich muss das Stück aus dem alten Buffer wegsichern ... */
            Memory.copy( tmp_buffer, &this.buffer[this.buffer_index], delta );
          }

          /* Die nächsten Daten lesen */
          this.dis.read( this.buffer );
          if ( delta != 0 )
          {
            /* Stückeln is angesagt => den zweiten Teil aus dem neuen Buffer lesen */
            Memory.copy( &tmp_buffer[delta], buffer, size - delta );
            this.buffer_index = size - delta;
          }
          else
          {
            this.buffer_index = 0;
          }
        }
        if ( delta == 0 || delta == size )
        {
          /* Da war keine Stückelung */
          Memory.copy( data, &this.buffer[this.buffer_index], size );
          this.buffer_index += size;
        }
        else
        {
          /* Ich habe gestückelt */
          Memory.copy( data, tmp_buffer, size );
        }
      }
      catch ( Error e )
      {
        error( "Error while reading from buffer! %s", e.message );
      }
    }

    public LogEntry? next_entry( )
    {
      if ( this.dis == null )
      {
        GLib.critical( "No Log-File opened!" );
        return null;
      }
      try
      {
        LogEntry e;
        uint16 record_type = 0;
        this.get_from_buffer( &record_type, sizeof(uint16) );
        if ( record_type == LOG_ENTRY_RECORD_TYPE_EOF )
        {
          stdout.printf("EOF of logfile reached\n");
          return null;
        }
        uint16 pid = 0;
        this.get_from_buffer( &pid, sizeof( uint16 ) );
        uint16 tid = 0;
        this.get_from_buffer( &tid, sizeof( uint16 ) );
        int64 tstamp = 0;
        this.get_from_buffer( &tstamp, sizeof( int64 ) );
        int64 file_id = 0;
        this.get_from_buffer( &file_id, sizeof( int64 ) );
        uint16 line = 0;
        this.get_from_buffer( &line, sizeof( uint16 ) );
        uint16 type = 0;
        this.get_from_buffer( &type, sizeof( uint16 ) );
        uint8 concat = 0;
        this.get_from_buffer( &concat, sizeof( uint8 ) );
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
        this.get_from_buffer( &trace_level, sizeof( uint16 ) );
        int64 message_id = 0;
        this.get_from_buffer( &message_id, sizeof( int64 ) );

        string component = this.read_string( );

        int16 parameter_count = 0;
        this.get_from_buffer( &parameter_count, sizeof( int16 ) );
        string[] tmp = {};
        for (int p = 0; p < parameter_count; p++)
        {
          tmp += this.read_string( );
        }
        e = new LogEntry(message_id, component, file_id, type, line, trace_level, concat_b);
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
