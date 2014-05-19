/*
 * Test-Programm für die dm_logger-Library
 */
 
public void main()
{
  DocuMatrix.Logger log = new DocuMatrix.Logger("test.log");
  DocuMatrix.log = log;
  DocuMatrix.log.start_threaded();
  DocuMatrix.log.debug(0, false, "Test-Log");
  string message = "Das ist nur eine Nachricht";
  DocuMatrix.log.debug(0, false, message);
  DocuMatrix.log.stop();
}

