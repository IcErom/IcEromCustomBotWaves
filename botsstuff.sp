#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes> //fixed

int wavenum = 1;
int wavenumcache = 1;
int g_iSuperBot = -1;
bool g_bEnableWaves = true;
bool g_bClassWarsEnabled = true;
bool g_bForceTeamsEnabled = true;
char g_cClassNames[9][13] = 
{ 
"scout",
"soldier",
"pyro",
"demoman",
"heavyweapons",
"engineer",
"medic",
"sniper",
"spy"
};
int g_iRandomLit = 0;
int g_iException1 = -1;
int g_iException2 = -1;

public void OnPluginStart() 
{
    RegConsoleCmd("sm_setwave", Command_SetWave, "Set the wave number for bots");
    RegConsoleCmd("sm_enablewavecache", Command_EnableWaveCache, "Enable or disable wave cache");
    RegConsoleCmd("sm_enablebotstuffwaves", Command_EnableWaves, "Enable the waves?");
    RegConsoleCmd("sm_enablesamebotsstuffclass", Command_SameBotClass, "Make them the same class? | CLass Wars.");
    RegConsoleCmd("sm_enableforcedbotsstuffteams", Command_ForceBotsStuffTeams, "If Enabled, Players on Red, Bots on blue.");
    
    HookEvent("teamplay_round_win", Event_RoundWin);
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // Intercept manual team menu clicks from players
    AddCommandListener(Listener_JoinTeam, "jointeam");
    
    // Apply server team restriction settings immediately
    if (g_bForceTeamsEnabled == true)
    {
    ApplyTeamSettings();
    }
}

public Action Command_ForceBotsStuffTeams(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_enableforcedbotsstuffteams <1/0>");
        return Plugin_Handled;
    }
    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    int enable = StringToInt(arg);
    if (enable == 1)
    {
        g_bForceTeamsEnabled = true;
        ReplyToCommand(client, "[SM] Force Team system ENABLED.");
    }
    else if (enable == 0)
    {
        g_bForceTeamsEnabled = false;
        ReplyToCommand(client, "[SM] Force Team system DISABLED.");
    }
    else
    {
        ReplyToCommand(client, "[SM] Invalid argument. Use 1 to enable or 0 to disable.");
    }
    return Plugin_Handled;
}


public void OnMapStart() 
{
    ApplyTeamSettings();
    
    PrintToServer("Server running botsstuff by IcErom/MIL4");
    if (wavenum && g_bEnableWaves)
    {
        PrintToServer("Wave: %d", wavenum);
    }
}

// Prevents TF2 from auto-balancing players.
void ApplyTeamSettings()
{
    ServerCommand("mp_limitteams 0");
    ServerCommand("mp_autoteambalance 0");
    ServerCommand("mp_teams_unbalance_limit 0");
    
    if (wavenum && g_bEnableWaves)
    {
        ServerCommand("tf_bot_quota %d", wavenum);
    }
}

// Block players from picking Blue via team selection screen
public Action Listener_JoinTeam(int client, const char[] command, int args)
{
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client))
    {
        return Plugin_Continue;
    }

    char sTeam[16];
    GetCmdArg(1, sTeam, sizeof(sTeam));
    int team = StringToInt(sTeam);

    // If a human player tries to join Blue (3) or Auto-select (0)
    if (g_bForceTeamsEnabled == true)
    {
    if (team == 0 || team == 3 && IsClientInGame(client) && !IsFakeClient(client))
    {
        // Force them to Red instead
        ChangeClientTeam(client, 2);
        TF2_RespawnPlayer(client);
        PrintToChat(client, "[SM] You are locked to RED team!");
        return Plugin_Handled; // Block the original team join command
    }
    }
    else
    {
        TF2_RespawnPlayer(client);
    }
    return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == 0 || !IsClientInGame(client))
    {
        return;
    }

    if (g_bForceTeamsEnabled)
    {
        int targetTeam = IsFakeClient(client) ? 3 : 2;
        if (GetClientTeam(client) != targetTeam)
        {
            ChangeClientTeam(client, targetTeam);
            return;
        }
    }
    if (client == g_iSuperBot && IsFakeClient(client) && GetClientTeam(client) == 3)
    {
        TF2_AddCondition(client, TFCond_CritCola, TFCondDuration_Infinite);
        TF2_AddCondition(client, TFCond_Buffed, TFCondDuration_Infinite);
    }
    // Class-war exceptions apply to Blue bots.
    if (!IsFakeClient(client) || GetClientTeam(client) != 3 || !g_bClassWarsEnabled)
    {
        return;
    }

    if (g_iRandomLit == 6) // Medic round: make one bot Heavy
    {
        if (g_iException1 == -1
            || !IsClientInGame(g_iException1)
            || GetClientTeam(g_iException1) != 3)
        {
            g_iException1 = client;
        }

        if (client == g_iException1
            && TF2_GetPlayerClass(client) != TFClass_Heavy)
        {
            TF2_SetPlayerClass(client, TFClass_Heavy, false, true);
            return;
        }
    }
    else if (g_iRandomLit == 5
        && (client == g_iException1 || client == g_iException2)
        && TF2_GetPlayerClass(client) != TFClass_Scout)
    {
        TF2_SetPlayerClass(client, TFClass_Scout, false, true);
    }
}

public void OnClientPutInServer(int client) 
{
    // Small delay to let client load before forcing initial team
    CreateTimer(0.5, Timer_ForceTeam, GetClientUserId(client));
}

public Action Timer_ForceTeam(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client))
    {
        return Plugin_Handled;
    }
    if (g_bForceTeamsEnabled == true)
    {
    if (IsFakeClient(client)) 
    {
        ChangeClientTeam(client, 3); // Force bot to Blue
    }
    else 
    {
        ChangeClientTeam(client, 2); // Force human to Red
    }
    }
    TF2_RespawnPlayer(client);
    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) // Medic and Engineer debugging.
{
    g_iException1 = -1;
    g_iException2 = -1;
    if (!g_bClassWarsEnabled)
        return;
    g_iRandomLit = GetRandomInt(0,8);
    if (g_iRandomLit == 6)
    {
        ServerCommand("tf_bot_force_class medic");
        g_iException1 = RandomBlueBot();
           
    }
    else if (g_iRandomLit == 5)
    {
        ServerCommand("tf_bot_force_class engineer");
        g_iException2 = RandomBlueBot();
        g_iException1 = RandomBlueBot();
        int attempts = 0;
        while (g_iException2 == g_iException1 && attempts < 10)
        {
            g_iException2 = RandomBlueBot();
            attempts++;
        }
    }
    else
    {
        ServerCommand("tf_bot_force_class %s", g_cClassNames[g_iRandomLit]);
    }
}

int RandomBlueBot()
{
    int bluebots[MAXPLAYERS + 1];
    int count = 0;

    for (int client = 1; client <= MaxClients; client++)
    {
        if ((IsClientInGame(client)) && IsFakeClient(client) && GetClientTeam(client) == 3)
        {
            bluebots[count++] = client;
        }
    }

    if (count == 0)
    {
        return -1;
    }
    return bluebots[GetRandomInt(0, count-1)];
}

public Action Command_EnableWaves(int client, int args) 
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_enablebotstuffwaves <1/0>");
        return Plugin_Handled;
    }
    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    int enable = StringToInt(arg);
    if (enable == 1)
    {
        g_bEnableWaves = true;
        ReplyToCommand(client, "[SM] Wave system ENABLED.");
    }
    else if (enable == 0)
    {
        g_bEnableWaves = false;
        ReplyToCommand(client, "[SM] Wave system DISABLED.");
    }
    else
    {
        ReplyToCommand(client, "[SM] Invalid argument. Use 1 to enable or 0 to disable.");
    }
    return Plugin_Handled;
}

public Action Command_EnableWaveCache(int client, int args) 
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_enablewavecache <1/0>");
        return Plugin_Handled;
    }
    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    int enable = StringToInt(arg);
    if (enable == 1)
    {
        wavenumcache = wavenum;
        ReplyToCommand(client, "[SM] Wave cache enabled. Current wave: %d", wavenumcache);
    }
    else if (enable == 0)
    {
        wavenumcache = 1; 
        ReplyToCommand(client, "[SM] Wave cache disabled. Resetting wave to: %d", wavenumcache);
    }
    else
    {
        ReplyToCommand(client, "[SM] Invalid argument. Use 1 to enable or 0 to disable.");
    }
    return Plugin_Handled;
}

public Action Command_SetWave(int client, int args) 
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_setwave <wave_number>");
        return Plugin_Handled;
    }
    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    wavenum = StringToInt(arg);
    ReplyToCommand(client, "[SM] Wave number has been set to: %d", wavenum);
    ServerCommand("tf_bot_quota %d", wavenum);
    return Plugin_Handled;
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast) 
{
    int winningTeam = event.GetInt("team");
    if (winningTeam == 2 && g_bEnableWaves) // Red wins
    {
        wavenum++;
        wavenumcache = wavenum;
        ServerCommand("tf_bot_quota %d", wavenum);
        PrintToServer("Wave increased to: %d", wavenum);
    }
    
    if (wavenum > wavenumcache && g_bEnableWaves)
    {
        if (g_bClassWarsEnabled == true)
        {
        ServerCommand("tf_bot_force_class %s", g_cClassNames[g_iRandomLit]); 
        }
    }
    
    if (wavenum % 3 == 0 && g_bEnableWaves)
    {
        g_iSuperBot = RandomBlueBot();
    }
}

public Action Command_SameBotClass(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[SM] Usage: sm_enablesamebotsstuffclass <1/0>");
        return Plugin_Handled;
    }
    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    int enable = StringToInt(arg);
    if (enable == 1)
    {
        g_bClassWarsEnabled = true;
        ServerCommand("tf_bot_force_class %s", g_cClassNames[g_iRandomLit]);
        ReplyToCommand(client, "[SM] Class Wars enabled.");
    }
    else if (enable == 0)
    {
        g_bClassWarsEnabled = false;
        ServerCommand("tf_bot_force_class \"\"");
        ReplyToCommand(client, "[SM] Class Wars disabled.");
    }
    else
    {
        ReplyToCommand(client, "[SM] Invalid argument. Use 1 to enable or 0 to disable.");
    }
    return Plugin_Handled;
}

public void OnClientDisconnected(int client)
{
    if (client == g_iSuperBot)
    {
        g_iSuperBot = -1; 
    }
}

public void ChangeWeaponFireRate(int client)
{

}