/**Avoid duplicate implementation**/
#if defined _interrogate_included_
   #endinput
#endif
#define _interrogate_included_

/**
*  Checks if a client is currently in an investigation
*
*  @param client     The client in question
*  @return           True means client is in investigation, false otherwise.
*/
native bool IsClientInInterrogation(int client);
