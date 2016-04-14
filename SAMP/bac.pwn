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
#define             CURRENT_VERSION                     "1.0.2"
#define             SERVER_MD5HASH                      "11101111 10111111 10111101 00010011 11101111 10111111 10111101 11101111 10111111 10111101 11101111 10111111 10111101 11101111 10111111 10111101 01001001 01000011 11101111 10111111 10111101 01111011 00101101 11101111 10111111 10111101 11101111 10111111 10111101 11101111 10111111 10111101 11101111 10111111 10111101 01010111"
#define             TIMERDELAY_CHECKAC                  5000 // (em MS) De quanto em quanto tempo o servidor vai pedir informações ao cliente.
#define         	TIMERDELAY_CONFIRMACCHECK           2000 // (em MS) É o tempo que demora o script a kickar ou não o jogador depois do anticheat enviar a resposta.
#define             TIMERDELAY_CHECKFORACONCONNECT      3000 // (em MS) É o tempo que demora o anticheat a atuar depois de o jogador se conectar.

#define 			COLOR_ORANGE            			0xFF9900AA

new Socket: bac_Socket[MAX_PLAYERS];
new bool: IsACConnected[MAX_PLAYERS];
new bool: IsCheater[MAX_PLAYERS];
new bool: UpdateNeeded[MAX_PLAYERS];
new CheckACTimer[MAX_PLAYERS];
new ConfirmACCheckTimer[MAX_PLAYERS];
new pUID[32][MAX_PLAYERS];
new Banido[MAX_PLAYERS];
new CheatsCount[MAX_PLAYERS];

forward GuardarStats(playerid, UID[]);
forward ConfirmACCheck(playerid);
forward CheckAC(playerid);
forward CheckForACOnConnect(playerid);
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
	UpdateNeeded[playerid] = false;
	Banido[playerid] = false;
	
	format(string, sizeof(string), "connected |%d| ,%s,", playerid, CURRENT_VERSION); // azeite
	
	socket_connect(bac_Socket[playerid], pIP, 4000);
	socket_send(bac_Socket[playerid], string, sizeof(string));
	
	SetTimerEx("CheckForACOnConnect", TIMERDELAY_CHECKFORACONCONNECT, false, "i", playerid);
    
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    socket_send(bac_Socket[playerid], "disconnect", 16);
	socket_destroy(bac_Socket[playerid]);
	
	KillTimer(ConfirmACCheckTimer[playerid]);
	KillTimer(CheckACTimer[playerid]);
	
	GuardarStats(playerid, pUID[playerid]);

	return 1;
}

public onSocketAnswer(Socket:id, data[], data_len)
{
	new playerid;
	new output[4][512];
	new md5Hash[512];
	
	explode(output, data, "'"); // template: [ playerid'status'UID'md5Hash ]
	
	playerid = strval(output[0]);
	pUID[playerid] = output[2];
	md5Hash = output[3];

	if(strfind(output[1], "secure", true) != -1)
	{
		playerid = strval(output[0]);
	    IsACConnected[playerid] = true;
	}
	else if(strfind(output[1], "cheater", true) != -1)
	{
		CheatsCount[playerid]++;
		
	    #if BAN_IF_CHEATER_ON_CONNECT == true
        SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Foste banido por cheats do servidor");
		Banido[playerid] = 1;
		#else
		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	    #endif
	}
	else if(strfind(output[1], "off", true) != -1)
	{
	    IsACConnected[playerid] = false;
	}
	else if(strfind(output[1], "online", true) != -1)
	{
	    IsACConnected[playerid] = true;
	}
	else if(strfind(output[1], "updateneed", true) != -1)
	{
	    IsACConnected[playerid] = true;
	    UpdateNeeded[playerid] = true;
	}
	else
	{
	    IsACConnected[playerid] = false;
	}
	
	if(strcmp(SERVER_MD5HASH, md5Hash))
	{
		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat foi modificado!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	
	return 1;
}

public CheckForACOnConnect(playerid)
{
	if(!IsPlayerConnected(playerid)) return 1;
	
	if(IsACConnected[playerid] == false)
	{
	    SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat não está ligado ou tens ficheiros suspeitos no teu computador!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(IsCheater[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(UpdateNeeded[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat está desactualizado!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else
	{
		new ficheiro[64];
		new pName[MAX_PLAYER_NAME];

		GetPlayerName(playerid, pName, sizeof(pName));
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
			return SetTimerEx("KickP", 50, false, "i", playerid);
		}
		
		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Conectado com sucesso!");
		CheckACTimer[playerid] = SetTimerEx("CheckAC", TIMERDELAY_CHECKAC, true, "i", playerid);
	}
	
	return 1;
}

public CheckAC(playerid)
{
	IsACConnected[playerid] = false;
 	IsCheater[playerid] = false;
	UpdateNeeded[playerid] = false;

	socket_send(bac_Socket[playerid], "check", 6);

	ConfirmACCheckTimer[playerid] = SetTimerEx("ConfirmACCheck", TIMERDELAY_CONFIRMACCHECK, false, "i", playerid);
}

public ConfirmACCheck(playerid)
{
	if(!IsPlayerConnected(playerid)) return 1;
	
	if(IsACConnected[playerid] == false)
	{
	    SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat não está ligado!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(IsCheater[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}Tens ficheiros suspeitos no teu computador!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
	}
	else if(UpdateNeeded[playerid] == true)
	{
 		SendClientMessage(playerid, COLOR_ORANGE, "[bANTICHEAT:] {FFFFFF}O teu anticheat está desactualizado!");
	    return SetTimerEx("KickP", 50, false, "i", playerid);
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
