/*

							 _       _          _   _  ____ _                _
							| |__   / \   _ __ | |_(_)/ ___| |__   ___  __ _| |_
							| '_ \ / _ \ | '_ \| __| | |   | '_ \ / _ \/ _` | __|
							| |_) / ___ \| | | | |_| | |___| | | |  __/ (_| | |_
							|_.__/_/   \_\_| |_|\__|_|\____|_| |_|\___|\__,_|\__|

*/

#include 			<a_samp>
#include 			<socket>
#include 			<strlib>
#include            <DOF2>

#define 			BAN_IF_CHEATER_ON_CONNECT 			false
#define 			COLOR_ORANGE            			0xFF9900AA

new Socket: bac_Socket[MAX_PLAYERS];
new bool: IsACConnected[MAX_PLAYERS];
new bool: IsCheater[MAX_PLAYERS];
new CheckACTimer[MAX_PLAYERS];
new KeepCheckingACTimer[MAX_PLAYERS];
new pUID[32][MAX_PLAYERS];
new Banido[MAX_PLAYERS];
new CheatsCount[MAX_PLAYERS];

forward GuardarStats(playerid, UID[]);
forward KeepCheckingAC(playerid);
forward CheckAC(playerid);
forward CheckForAC(playerid);
forward KickP(playerid);

public OnFilterScriptInit()
{
	print("\n ** A CARREGAR BANTICHEAT ** \n");
	
	return 1;
}

public OnFilterScriptExit()
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(!IsPlayerConnected(i)) continue;
        socket_destroy(bac_Socket[i]);
        GuardarStats(i, pUID[i]);
    }
    
    print("\n ** BANTICHEAT TERMINADO ** \n");
		
	return 1;
}

public OnPlayerConnect(playerid)
{
	new pIP[16];
	new string[32];
	
	bac_Socket[playerid] = socket_create(TCP);
    GetPlayerIp(playerid, pIP, sizeof(pIP));
    
	IsACConnected[playerid] = false;
	IsCheater[playerid] = false;
	
	format(string, sizeof(string), "connected %d", playerid);
	
	socket_connect(bac_Socket[playerid], pIP, 4000);
	socket_send(bac_Socket[playerid], string, sizeof(string));
	
	SetTimerEx("CheckForAC", 10000, false, "i", playerid);
    
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    socket_send(bac_Socket[playerid], "closeac", 16);
	socket_destroy(bac_Socket[playerid]);
	
	KillTimer(KeepCheckingACTimer[playerid]);
	KillTimer(CheckACTimer[playerid]);
	
	GuardarStats(playerid, pUID[playerid]);

	return 1;
}

public onSocketAnswer(Socket:id, data[], data_len)
{
	new playerid;
	new output[3][32];
	new ficheiro[64];
	new pName[MAX_PLAYER_NAME];

	GetPlayerName(playerid, pName, sizeof(pName));
	
	strexplode(output, data, "'"); // template: [ playerid'status'UID ]
	
	pUID[playerid] = output[2];

	format(ficheiro, sizeof(ficheiro), "bAntiCheat/%s.ini", pUID[playerid]);
	
	if(!DOF2_FileExists(ficheiro))
	{
	    DOF2_CreateFile(ficheiro);
	    
	    DOF2_SetString(ficheiro, "UID", pUID[playerid]);
	    DOF2_SetInt(ficheiro, "Banido", 0);
	    DOF2_SetInt(ficheiro, "CheatsCount", 0);
	    DOF2_SetString(ficheiro, "LastName", pName);
	    
	    DOF2_SaveFile();
	}
	else
	{
	    Banido[playerid] = DOF2_GetInt(ficheiro, "Banido");
	    CheatsCount[playerid] = DOF2_GetInt(ficheiro, "CheatsCount");
	}
	
	if(Banido[playerid] == 1)
	{
	    SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Estás banido do servidor");
		SetTimerEx("KickP", 50, false, "i", playerid);
	}
	
	if(strcmp(output[1], "secured"))
	{
		playerid = strval(output[0]);
	    IsACConnected[playerid] = true;
	}
	else if(strcmp(output[1], "cheater"))
	{
		CheatsCount[playerid]++;
		
	    #if BAN_IF_CHEATER_ON_CONNECT == true
        SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Foste banido por cheats do servidor");
		Banido[playerid] = 1;
		#else
		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    SetTimerEx("KickP", 50, false, "i", playerid);
	    #endif
	}
	else if(strcmp(output[1], "off"))
	{
	    IsACConnected[playerid] = false;
	}
	else if(strcmp(output[1], "on"))
	{
	    IsACConnected[playerid] = true;
	}
	else
	{
	    IsACConnected[playerid] = false;
	}
	
	return 1;
}

public CheckForAC(playerid)
{
	if(!IsPlayerConnected(playerid)) return 1;
	
	if(IsACConnected[playerid] == false)
	{
	    SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat não está ligado ou tens ficheiros suspeitos no teu computador!");
	    SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(IsCheater[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else
	{
		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Conectado com sucesso!");
		CheckACTimer[playerid] = SetTimerEx("CheckAC", 5000, true, "i", playerid);
		KeepCheckingACTimer[playerid] = SetTimerEx("KeepCheckingAC", 5000, true, "i", playerid);
	}
	return 1;
}

public CheckAC(playerid)
{
    IsACConnected[playerid] = false;
    IsCheater[playerid] = false;
    
	socket_send(bac_Socket[playerid], "check", 6);
}

public KeepCheckingAC(playerid)
{
	if(!IsPlayerConnected(playerid)) return 1;
	
	if(IsACConnected[playerid] == false)
	{
	    SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat não está ligado!");
	    SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(IsCheater[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    SetTimerEx("KickP", 50, false, "i", playerid);
	}
    
	return 1;
}

public GuardarStats(playerid, UID[])
{
	new ficheiro[64];
	new pName[MAX_PLAYER_NAME];

	GetPlayerName(playerid, pName, sizeof(pName));

	format(ficheiro, sizeof(ficheiro), "bAntiCheat/%s.ini", UID);

    DOF2_SetInt(ficheiro, "Banido", Banido[playerid]);
    DOF2_SetInt(ficheiro, "CheatsCount", CheatsCount[playerid]);
    DOF2_SetString(ficheiro, "LastName", pName);

	DOF2_SaveFile();
}

public KickP(playerid) Kick(playerid);
