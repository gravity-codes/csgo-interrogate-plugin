# Bazooka's CS:GO Interrogate Plugin
![GitHub](https://img.shields.io/github/license/bazooka-codes/csgo-interrogate-plugin) ![Github All Releases](https://img.shields.io/github/downloads/bazooka-codes/csgo-interrogate-plugin/total)

This plugin is designed to allow an admin to drag a connected client into a 1 on 1 conversation where they can only hear each other and no one else can hear them. Hopefully this eliminates any excuses about clients "not hearing admins". The plugin functions by displaying menus to the admin trying to interrogate. The plugin now incorporates the admin menu feature of sourcemod. The two included configs files "adminmenu_custom.txt" and "adminmenu_sorting.txt" add Interrogate to the "Player Commands" section of the admin menu. Do not download these files if you do not want this feature.

## Usage
The plugin uses the commands !interrogate and !intg.
If no arguments are provided, a menu of all current connected clients is displayed. When the admin selects an item, the interrogation of that client will begin.
If a name is given as an argument, the plugin will check for any duplicate matches. If any duplicates are found, another menu with the possible matches is shown for the admin to select. If not, the interrogation of the matching client immediately begins.
