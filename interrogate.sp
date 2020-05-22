/*
   - v0.1.2 Working except for on round change
*/

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#define VERSION "0.1.2"
#pragma newdecls required

Handle Cvar_Intg = INVALID_HANDLE;
Handle Cvar_Debug = INVALID_HANDLE;
bool in_interrogation = false;
int interrogater = 0;
int interrogatee = 0;
char interrogateeName[MAX_NAME_LENGTH];

public Plugin myinfo =
{
   name = "Bazooka's Interrogate Plugin",
   description = "Plugin that allows an admin to drag a player into a 1v1 conversation.",
   author = "bazooka",
   version = VERSION,
   url = "https://github.com/bazooka-codes"
};

public void OnPluginStart()
{
   CreateConVar("sm_interrogate_version", VERSION, "Bazooka's interrogate plugin version.");
   Cvar_Intg = CreateConVar("sm_interrogate_enable", "1", "1 - Interrogate plugin enabled | 0 - Interrogate plugin disabled");
   Cvar_Debug = CreateConVar("sm_interrogate_debug", "0", "1 - Interrogate plugin debug mode | 0 - Interrogate debug disabled.");

   RegAdminCmd("interrogate", InterrogateHandler, ADMFLAG_GENERIC);
   RegAdminCmd("intg", InterrogateHandler, ADMFLAG_GENERIC);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   CreateNative("IsClientInInterrogation", Native_Interrogate_Include);
   return APLRes_Success;
}

public void OnMapEnd()
{
   //Reset all comms on map change
   if(GetConVarInt(Cvar_Intg) != 1)
   {
      return;
   }

   //If map ends during interrogation
   if(in_interrogation)
   {
      EndInterrogate("Map ended.");
   }
}

public void OnClientConnected(int client)
{
   if(GetConVarInt(Cvar_Intg) != 1)
   {
      //Plugin disabled
      return;
   }

   //If someone joins while interrogating, disable the hearing for connecting player
   if(in_interrogation)
   {
      SetListenOverride(client, interrogater, Listen_No);
      SetListenOverride(interrogater, client, Listen_No);

      SetListenOverride(client, interrogatee, Listen_No);
      SetListenOverride(interrogatee, client, Listen_No);

      CPrintToChat(client, "{orchid}Interrogate: {default}Interrogation in progess. You may not be able to reach certain players.");
      CPrintToChat(interrogater, "{orchid}Interrogate: {default}New client joined and was muted.");
   }
}

public void OnClientDisconnect(int client)
{
   //If someone leaves when interrogation is happening, reset their
   if(in_interrogation)
   {
      if(client == interrogatee)
      {
         EndInterrogate("Target disconnected.");
      }

      if(client == interrogater)
      {
         EndInterrogate("Admin disconnected.");
      }
   }
}

public Action InterrogateHandler(int client, int args)
{
   if(GetConVarInt(Cvar_Intg) != 1)
   {
      //Plugin is disabled
      return Plugin_Stop;
   }

   if(!IsClientInGame(client))
   {
      //Client disconnected
      return Plugin_Handled;
   }

   if(!CheckCommandAccess(client, "", ADMFLAG_GENERIC))
   {
      //Client is not an admin
      CReplyToCommand(client, "{orchid}Interrogate: {default}ERROR - You do not have access to this command.");
      return Plugin_Handled;
   }

   if(in_interrogation)
   {
      //Client is trying to start interrogation while already in one
      CReplyToCommand(client, "{orchid}Interrogate: {default}ERROR - Already in interrogation. Please end current interrogation and try again.");
      return Plugin_Handled;
   }

   if(GetClientMenu(client, INVALID_HANDLE) != MenuSource_None)
   {
      //Stop client from trying to pull up another menu with one already open
      CReplyToCommand(client, "{orchid}Interrogate: {default}ERROR - Cannot display menu as client already has menu open. Please close current menu and try again.");
      return Plugin_Handled;
   }

   if(GetCmdArgs() == 1) //Client entered target name
   {
      //Loop through current clients for matching name
      char targetArg[MAX_NAME_LENGTH];
      GetCmdArg(1, targetArg, sizeof(targetArg));
      int timesFound = 0;
      int matchclient = 0;
      Menu menu = new Menu(InterrogateMenu, MENU_ACTIONS_ALL);
      menu.SetTitle("Found Multiple Matches:");

      for(int i = 1; i < GetClientCount(true); i++)
      {
         if(!IsClientInGame(i))
         {
            continue;
         }

         char temp[MAX_NAME_LENGTH];
         GetClientName(i, temp, sizeof(temp));

         if(StrEqual(targetArg, temp, false) || StrContains(temp, targetArg, false) != -1)
         {
            timesFound++;
            matchclient = i;

            char tempid[12];
            IntToString(GetClientUserId(i), tempid, sizeof(tempid));
            menu.AddItem(tempid, temp);
         }
      }

      if(timesFound == 0)
      {
         CReplyToCommand(client, "{orchid}Interrogate: {default}Unable to locate client: %s. Check spelling and try again, or type \"!intg\" or \"!interrogate\" to choose from all connected clients.", targetArg);
      }
      else if(timesFound == 1)
      {
         Interrogate(client, matchclient);
      }
      else
      {
         CReplyToCommand(client, "{orchid}Interrogate: {default}Multiple matches found. Please choose correct target.");
         menu.Display(client, MENU_TIME_FOREVER);
      }

      return Plugin_Continue;
   }

   if(GetCmdArgs() != 0) //Invalid command line usage
   {
      CReplyToCommand(client, "{orchid}Interrogate: {default}ERROR - Invalid command syntax. (!intg | !interrogate <username>)");
      return Plugin_Handled;
   }

   //Create menu for client to choose target
   Menu menu = new Menu(InterrogateMenu, MENU_ACTIONS_ALL);
   menu.SetTitle("Choose Target");

   for(int target = 1; target <= GetClientCount(true); target++)
   {
      if(!IsClientInGame(target) || target == client)
      {
         //Skip if target left or found own client
         continue;
      }

      char targetid[12];
      char targetName[MAX_NAME_LENGTH];
      IntToString(GetClientUserId(target), targetid, sizeof(targetid));
      GetClientName(target, targetName, sizeof(targetName));
      menu.AddItem(targetid, targetName);
   }

   menu.Display(client, MENU_TIME_FOREVER);

   return Plugin_Handled;
}

public Action Interrogate(int client, int target)
{
   if(GetConVarInt(Cvar_Intg) != 1)
   {
      return Plugin_Stop;
   }

   if(!IsClientInGame(client))
   {
      //Client disconnected
      return Plugin_Continue;
   }

   if(!IsClientInGame(target))
   {
      CReplyToCommand(client, "{orchid}Interrogate: {default}ERROR - Target not in game.");
      return Plugin_Handled;
   }

   SetListenOverride(client, target, Listen_Yes);
   SetListenOverride(target, client, Listen_Yes);

   for(int i = 1; i <= GetClientCount(true); i++)
   {
      if(i == client || i == target || !IsClientInGame(i))
      {
         continue;
      }

      SetListenOverride(i, client, Listen_No);
      SetListenOverride(client, i, Listen_No);

      SetListenOverride(i, target, Listen_No);
      SetListenOverride(target, i, Listen_No);
   }

   in_interrogation = true;
   interrogater = client;
   interrogatee = target;
   GetClientName(target, interrogateeName, sizeof(interrogateeName));

   Menu endMenu = new Menu(EndInterrogateMenu, MENU_ACTIONS_ALL);
   endMenu.SetTitle("Active interrogation: %s", interrogateeName);
   endMenu.AddItem("done", "End interrogation");
   endMenu.ExitButton = false;
   endMenu.Display(interrogater, MENU_TIME_FOREVER);

   CReplyToCommand(interrogater, "{orchid}Interrogate: {default}Interrogation of target \"%s\" has successfully been started.", interrogateeName);
   CPrintToChat(client, "{orchid}Interrogate: {default}You are now being interrogated.");

   return Plugin_Continue;
}

public void EndInterrogate(char[] reason)
{
   char targetName[MAX_NAME_LENGTH];

   if(interrogater == 0 || interrogatee == 0)
   {
      CPrintToServer("Interrogate: ERROR - Trying to end nonexistent interrogation.");
   }

   if(IsClientInGame(interrogatee))
   {
      GetClientName(interrogatee, targetName, sizeof(targetName));
      CPrintToChat(interrogatee, "{orchid}Interrogate: {default}Interrogation has no ended.");
      resetListen(interrogatee);
   }

   if(IsClientInGame(interrogater))
   {
      if(!IsClientInGame(interrogatee))
      {
         //If interrogatee leaves, we need to remove menu from interrogater's screen
         CancelClientMenu(interrogater, false, INVALID_HANDLE);
      }

      CPrintToChat(interrogater, "{orchid}Interrogate: {default}Interrogation of %s ended. Reason: %s", targetName, reason);
      resetListen(interrogater);
   }

   in_interrogation = false;
   interrogater = 0;
   interrogatee = 0;
}

public int InterrogateMenu(Menu menu, MenuAction action, int param1, int param2)
{  //I left all cases here just in case in the future I want to use them
   switch(action)
   {
      case MenuAction_Select: //Called when client makes selection
      {
         char t_string[32];
         menu.GetItem(param2, t_string, sizeof(t_string));
         int target = StringToInt(t_string);
         target = GetClientOfUserId(target);

         if(target == 0)
         {
            //Error getting client
            CPrintToChat(param1, "{orchid}Interrogate: {default}ERROR - Unable to interrogate.");
         }

         Interrogate(param1, target);
      }

      case MenuAction_Cancel: //Called when client closes menu
      {
         char choice[32];
         menu.GetItem(param2, choice, sizeof(choice));

         if(StrEqual(choice, "MenuAction_Select"))
         {
            CPrintToChat(param1, "{orchid}Interrogate: {default}Interrogation has begun.");
         }
         else
         {
            CPrintToChat(param1, "{orchid}Interrogate: {default}Interrogation aborted.")
         }
      }
   }

   return 0;
}

public int EndInterrogateMenu(Menu menu, MenuAction action, int param1, int param2)
{
   if(action == MenuAction_Select)
   {
      char choice[32]
      menu.GetItem(param2, choice, sizeof(choice));

      if(StrEqual(choice, "done"))
      {
         EndInterrogate("Successfully completed interrogation.");
      }
   }
}

public void resetListen(int client)
{
   if(!IsClientInGame(client))
   {
      return;
   }

   for(int i = 1; i <= GetClientCount(true); i++)
   {
      if(i == client || !IsClientInGame(i))
      {
         continue;
      }

      SetListenOverride(client, i, Listen_Default);
      SetListenOverride(i, client, Listen_Default);
   }
}

public void DEBUG_PRINT(char[] str)
{
   if(GetConVarInt(Cvar_Debug) == 1)
   {
      PrintToServer("DEBUG (Interrogate): %s", str);
   }
}

public int Native_Interrogate_Include(Handle plugin, int numParams)
{
   int client = GetNativeCell(1);

   if(!in_interrogation)
   {
      return false;
   }

   if(client == 0 || interrogater == 0 || interrogatee == 0)
   {
      return false;
   }

   if(client == interrogater || client == interrogatee)
   {
      return true;
   }

   return false;
}
