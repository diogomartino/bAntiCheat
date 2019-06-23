#include 		<a_samp>
#include 		<socket>
#include 		<strlib>
#include        <sscanf2>
#include        <zcmd>

#define 		MAX_SAVED_CONNECTIONS   		MAX_PLAYERS + 50
#define 		DIALOG_BAC_JOINCODE     		1547
#define 		DIALOG_BAC_MSG          		947

#define         TAG_COLOR                       0xff3a3a

#define 		SOCKET_IP               		"0.0.0.0"
#define 		SOCKET_PORT             		9014
#define 		SOCKET_MAX_CONNECTIONS  		100

#define 		IS_ALIVE_TIME	  				1000 // Ping-Pong time. If your players have high ping, you should use a higher time.
#define 		IS_ALIVE_KICK_WAIT  			800 // Time that the server waits to kick the player after the ping request was made
#define         MAX_BANLIST             		10 // Total banned UID's the server can handle

#define         SECURITY_CODE           		"2820CBC9C2BDD028967500F234B17DE5B0E7B83B8E6D98E9ADB149F427643E3C" // AntiCheat client checksum (NEEDS TO BE IN UPPERCASE)
#define         SCHEMA_URL                      "https://pastebin.com/raw/sKJzYnAx"

enum e_ConnectionInfo
{
	UniqueID[64+1],
	SecurityID[64+1],
	JoinCode,
	ValidUntil,
	RemoteId,
	bool:Used,
	Ip[16],
	bool:Binded,
	pId,
};
new connInfo[MAX_SAVED_CONNECTIONS][e_ConnectionInfo];

enum e_PlayerInfo
{
	ConnId,
	PingTimer,
	PongTimer,
	bool:Ponged
};
new bac_PlayerInfo[MAX_PLAYERS][e_PlayerInfo];

new Socket:sSocket;
new BanList[MAX_BANLIST][70];

public OnFilterScriptInit() {
    print("\n\n=================================================");
	print("bAnticheat by bruxo loading");
	printf("\nListening on: %s:%d", SOCKET_IP, SOCKET_PORT);
	printf("Max Connections: %d", SOCKET_MAX_CONNECTIONS);
	printf("Is Alive Time: %d ms", IS_ALIVE_TIME);
	printf("Is Alive Time Kick Wait: %d ms", IS_ALIVE_KICK_WAIT);
	printf("Ban List Max: %d", MAX_BANLIST);
	printf("Schema: %s", SCHEMA_URL);

 	sSocket = socket_create(TCP);

  	if(is_socket_valid(sSocket)) {
   		socket_set_max_connections(sSocket, SOCKET_MAX_CONNECTIONS);
   		socket_bind(sSocket, SOCKET_IP);
     	socket_listen(sSocket, SOCKET_PORT);
    }

    SetTimer("CleanConnections", 1000, true);

    ReadAllBansFromFile();

    print("\nLoaded.");
    print("=================================================\n\n");

	return 1;
}

public OnPlayerDisconnect(playerid, reason) {
	if(bac_PlayerInfo[playerid][ConnId] != -1) {
	    socket_sendto_remote_client(sSocket, connInfo[bac_PlayerInfo[playerid][ConnId]][RemoteId], "DSCN");
	    connInfo[bac_PlayerInfo[playerid][ConnId]][Used] = false;
	}

    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    if(dialogid == DIALOG_BAC_JOINCODE) {
   		new string[128];
 		new sdialog[512];

        if(!response) KickEx(playerid);

		new JCode = strval(inputtext);
		new bool:found = false;

		for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
			if(connInfo[i][Used]) {
		   		new pIP[16];
		   		GetPlayerIp(playerid, pIP, sizeof(pIP));

				if(isequal(pIP, connInfo[i][Ip])) {
					found = true;
					if(JCode == connInfo[i][JoinCode]) {
						bac_PlayerInfo[playerid][ConnId] = i;
						connInfo[i][Binded] = true;
						connInfo[i][pId] = playerid;

						if(isUIDBanned(connInfo[i][UniqueID])) {
							format(sdialog, sizeof sdialog, "");
							format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
							format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
							format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
							format(string, sizeof(string), "\n\n{ffffff}This server is protected by bAntiCheat."); strcat(sdialog,string);
							format(string, sizeof(string), "\n\n\n{fc2828}You are permanently banned from this server."); strcat(sdialog,string);

			                ShowPlayerDialog(playerid, DIALOG_BAC_MSG, DIALOG_STYLE_MSGBOX, "bAntiCheat", sdialog, "Ok", "");
			                KickEx(playerid);
						} else {
				    		new pName[MAX_PLAYER_NAME], str[40];
		    				GetPlayerName(playerid, pName, sizeof pName);

							format(str, sizeof str, "WELCOME:%s", pName);
							socket_sendto_remote_client(sSocket, connInfo[i][RemoteId], str);

							bac_PlayerInfo[playerid][PingTimer] = SetTimerEx("Ping", 5000, false, "i", i);
						}
					} else {
						format(sdialog, sizeof sdialog, "");
						format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
						format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
						format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
						format(string, sizeof(string), "\n\n{ffffff}This server is protected by bAntiCheat."); strcat(sdialog,string);
						format(string, sizeof(string), "\n{ff3a3a}bAntiCheat {ffffff}is a anti-cheat client. You can download it from: {00f790}https://example.com"); strcat(sdialog,string);
						format(string, sizeof(string), "\n{ffffff}Please enter the join code that appears in your client."); strcat(sdialog,string);
						format(string, sizeof(string), "\n{ffffff}If you don't do this, you will not be able to play in this server."); strcat(sdialog,string);
						format(string, sizeof(string), "\n\n\n{fc2828}The code you entered is incorrect. Try again."); strcat(sdialog,string);

                        ShowPlayerDialog(playerid, DIALOG_BAC_JOINCODE, DIALOG_STYLE_INPUT, "bAntiCheat", sdialog, "Proceed", "Quit");
					}
					break;
				}
			}

			if(!found) {
				format(sdialog, sizeof sdialog, "");
				format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
				format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
				format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
				format(string, sizeof(string), "\n\n{ffffff}This server is protected by bAntiCheat."); strcat(sdialog,string);
				format(string, sizeof(string), "\n{ff3a3a}bAntiCheat {ffffff}is a anti-cheat client. You can download it from: {00f790}https://example.com"); strcat(sdialog,string);
				format(string, sizeof(string), "\n{ffffff}Please enter the join code that appears in your client."); strcat(sdialog,string);
				format(string, sizeof(string), "\n{ffffff}If you don't do this, you will not be able to play in this server."); strcat(sdialog,string);
				format(string, sizeof(string), "\n\n\n{fc2828}Your connection is no longer valid. Please connect your anticheat again and rejoin."); strcat(sdialog,string);

                ShowPlayerDialog(playerid, DIALOG_BAC_MSG, DIALOG_STYLE_MSGBOX, "bAntiCheat", sdialog, "Ok", "");
                KickEx(playerid);
			}
		}
    }

    return 0;
}

public OnPlayerConnect(playerid) {
	new string[128];
	new sdialog[512];

	bac_PlayerInfo[playerid][ConnId] = -1;

	new bool: found = false;

	for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
		if(connInfo[i][Used]) {
			new pIP[16];
 			GetPlayerIp(playerid, pIP, sizeof(pIP));

			if(isequal(pIP, connInfo[i][Ip])) {
			    found = true;
			    break;
			}
		}
	}

	if(!found) {
	    format(sdialog, sizeof sdialog, "");
		format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
		format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
		format(string, sizeof(string), "\n\n{ffffff}This server is protected by bAntiCheat."); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ff3a3a}bAntiCheat {ffffff}is a anti-cheat client. You can download it from: {00f790}https://example.com"); strcat(sdialog,string);
        format(string, sizeof(string), "\n\n\n{fc2828}It seems like you don't have your Anti Cheat client running or you took too long to join the server."); strcat(sdialog,string);

		ShowPlayerDialog(playerid, DIALOG_BAC_MSG, DIALOG_STYLE_MSGBOX, "bAntiCheat", sdialog, "Quit", "");
		KickEx(playerid);
	} else {
	    format(sdialog, sizeof sdialog, "");
		format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
		format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
		format(string, sizeof(string), "\n\n{ffffff}This server is protected by bAntiCheat."); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ff3a3a}bAntiCheat {ffffff}is a anti-cheat client. You can download it from: {00f790}https://example.com"); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ffffff}Please enter the join code that appears in your client."); strcat(sdialog,string);
		format(string, sizeof(string), "\n{ffffff}If you don't do this, you will not be able to play in this server."); strcat(sdialog,string);

		ShowPlayerDialog(playerid, DIALOG_BAC_JOINCODE, DIALOG_STYLE_INPUT, "bAntiCheat", sdialog, "Proceed", "Quit");
	}

    return 1;
}

public onSocketReceiveData(Socket:id, remote_clientid, data[], data_len) {
	new output[2][512];
	strexplode(output, data, ":");

	if(isequal(output[0], "CONNECTED")) {
		new info[3][64+1];
		strexplode(info, output[1], "|");
		
		if(!isequal(SECURITY_CODE, info[1])) {
		    socket_sendto_remote_client(id, remote_clientid, "WRONG_SEC_CODE");
		    return 1;
		}
		
		for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
			if(connInfo[i][Used] && isequal(info[0], connInfo[i][UniqueID])) {
			    if(connInfo[i][Binded] == false) {
			        connInfo[i][Used] = false;
			    } else {
			        return 1;
			    }
				break;
			}
    	}

		for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
			if(!connInfo[i][Used]) {
   				connInfo[i][Used] = true;
				connInfo[i][UniqueID] = info[0];
				connInfo[i][SecurityID] = info[1];
				connInfo[i][RemoteId] = remote_clientid;
				connInfo[i][JoinCode] = strval(info[2]);
				connInfo[i][ValidUntil] = gettime() + 120;
				connInfo[i][Binded] = false;
				get_remote_client_ip(id, remote_clientid, connInfo[i][Ip]);

				printf("[bAntiCheat NEW CONNECTION]");
				printf("Join Code: %d", connInfo[i][JoinCode]);
				printf("IP: %s", connInfo[i][Ip]);
				printf("UID: %s", connInfo[i][UniqueID]);

				new string[64];
				format(string, sizeof string, "CONNECTED|%s", SCHEMA_URL);
				socket_sendto_remote_client(sSocket, remote_clientid, string);
				break;
			}
    	}
 	} else if(isequal(output[0], "PONG")) {
		new cId = FindConnectionID(output[1]);
		if(cId != -1) {
   			bac_PlayerInfo[connInfo[cId][pId]][Ponged] = true;
		}
 	} else if(isequal(output[0], "DROP")) {
		new cId = FindConnectionID(output[1]);
		if(cId != -1) {
   			KickEx(connInfo[cId][pId]);
		}
 	}

	return 1;
}

forward ReadAllBansFromFile();
public ReadAllBansFromFile() {
	new File:handler = fopen("bac/uids.txt", io_read);

	if(handler) {
	  	new string[64+1];

	  	while(fread(handler, string)) {
			strtrim(string);
			if(!isempty(string)) {
				for(new i = 0; i < MAX_BANLIST; i++) {
					if(isempty(BanList[i])) {
					    BanList[i] = string;
					    break;
					}
				}
			}
			fclose(handler);
	  	}
	}

	return 1;
}

forward CleanConnections();
public CleanConnections() {
    for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
        if(connInfo[i][Used] && !connInfo[i][Binded] && connInfo[i][ValidUntil] < gettime()) {
            connInfo[i][Used] = false;
            socket_sendto_remote_client(sSocket, connInfo[i][RemoteId], "DSCN");
        }
    }

	return 1;
}

forward Ping(connectionId);
public Ping(connectionId) {
    socket_sendto_remote_client(sSocket, connInfo[connectionId][RemoteId], "PING");
    bac_PlayerInfo[connInfo[connectionId][pId]][PongTimer] = SetTimerEx("Pong", IS_ALIVE_KICK_WAIT, false, "i", connectionId);

	return 1;
}

forward Pong(connectionId);
public Pong(connectionId) {
	if(!bac_PlayerInfo[connInfo[connectionId][pId]][Ponged]) {
		SendClientMessage(connInfo[connectionId][pId], TAG_COLOR, "[bAnticheat:] {ffffff}The connection with your anticheat client has been lost.");
	    KickEx(connInfo[connectionId][pId]);
	} else {
		bac_PlayerInfo[connInfo[connectionId][pId]][PingTimer] = SetTimerEx("Ping", IS_ALIVE_TIME, false, "i", connectionId);
		bac_PlayerInfo[connInfo[connectionId][pId]][Ponged] = false;
	}

	return 1;
}

forward PermaBanEx(playerid);
public PermaBanEx(playerid) {
    SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}You have been permanently banned.");
    addBan(connInfo[bac_PlayerInfo[playerid][ConnId]][UniqueID]);
    SetTimerEx("BanNow", 100, false, "i", playerid);
	return 1;
}

forward BanNow(playerid);
public BanNow(playerid) {
    Ban(playerid);
	return 1;
}

forward KickEx(playerid);
public KickEx(playerid) {
	SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}You have been kicked.");
    SetTimerEx("KickNow", 100, false, "i", playerid);
	return 1;
}

forward KickNow(playerid);
public KickNow(playerid) {
    Kick(playerid);
	return 1;
}

stock FindConnectionID(uID[]) {
	for(new i = 0; i < MAX_SAVED_CONNECTIONS; i++) {
		if(connInfo[i][Used]) {
			if(isequal(uID, connInfo[i][UniqueID])) {
			    return i;
			}
		}
	}
	return -1;
}

stock GetPlayerNameEx(playerid)
{
    new pName[MAX_PLAYER_NAME];
    GetPlayerName(playerid, pName, MAX_PLAYER_NAME);
    return pName;
}

stock IsPlayerAdminEx(playerid) { // use your own admin variable
	if(IsPlayerAdmin(playerid)) {
	    return true;
	}
	return false;
}

stock isUIDBanned(uID[]) {
	for(new i = 0; i < MAX_BANLIST; i++) {
		if(!isempty(BanList[i]) && isequal(uID, BanList[i])) {
			return true;
		}
	}
	return false;
}

stock addBan(uID[]) {
    new File:handler = fopen("bac/uids.txt", io_append);

	if(handler) {
		new string[64+1];
		format(string, sizeof string, "%s\r\n", uID);
        fwrite(handler, string);
        fclose(handler);
	}

    ReadAllBansFromFile();
}

CMD:bacinfo(playerid, params[])
{
    new targetid;

    if(sscanf(params, "d", targetid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}/bacinfo <playerid>");
    if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}Target is not connected.");
    if(!IsPlayerAdminEx(playerid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}Permission denied.");

	new sdialog[550], string[128];

	format(sdialog, sizeof sdialog, "");
	format(string, sizeof(string), "{f6ff00}====================="); strcat(sdialog,string);
	format(string, sizeof(string), "\n{ffffff}\tbAnticheat"); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f6ff00}====================="); strcat(sdialog,string);
	format(string, sizeof(string), "\n\n{ffffff}Information about {f6ff00}%s.", GetPlayerNameEx(targetid)); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Unique ID: {ffffff}%s", connInfo[bac_PlayerInfo[playerid][ConnId]][UniqueID]); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Security ID: {ffffff}%s", connInfo[bac_PlayerInfo[playerid][ConnId]][SecurityID]); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Join Code: {ffffff}%d", connInfo[bac_PlayerInfo[playerid][ConnId]][JoinCode]); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Connected from: {ffffff}%s", connInfo[bac_PlayerInfo[playerid][ConnId]][Ip]); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Connection ID: {ffffff}%d", bac_PlayerInfo[playerid][ConnId]); strcat(sdialog,string);
	format(string, sizeof(string), "\n{f98518}Remote ID: {ffffff}%d", connInfo[bac_PlayerInfo[playerid][ConnId]][RemoteId]); strcat(sdialog,string);

	ShowPlayerDialog(playerid, DIALOG_BAC_MSG, DIALOG_STYLE_MSGBOX, "bAntiCheat", sdialog, "Ok", "");

    return 1;
}

CMD:bacban(playerid, params[])
{
    new targetid;

    if(sscanf(params, "d", targetid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}/bacban <playerid>");
    if(!IsPlayerConnected(targetid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}Target is not connected.");
    if(!IsPlayerAdminEx(playerid)) return SendClientMessage(playerid, TAG_COLOR, "[bAnticheat:] {ffffff}Permission denied.");

    new string[128];

    format(string, sizeof string, "[bAnticheat:] {ffffff}You permanently banned %s from this server.", GetPlayerNameEx(targetid));
    SendClientMessage(playerid, TAG_COLOR, string);

	PermaBanEx(targetid);

    return 1;
}

