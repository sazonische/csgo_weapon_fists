#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1
#pragma newdecls required

int g_vecOrigin,
	g_ownerEntity;

bool g_isForceKnifeInSpawn[MAXPLAYERS + 1];

Cookie g_cookieWeaponFists;
ConVar mp_drop_knife_enable;

public Plugin myinfo = {
    name        = "CS:GO Weapon fists (mmcs.pro)",
    author      = "SAZONISCHE",
    version     = "1.5",
    url         = "mmcs.pro"
};

public void OnPluginStart() {
	// Plugin only for csgo
	if (GetEngineVersion() != Engine_CSGO) {
		SetFailState("This plugin is for CSGO only.");
	}

	g_vecOrigin = FindSendPropInfo("CBasePlayer", "m_vecOrigin");
	if (g_vecOrigin == -1) {
		SetFailState("Failed to obtain offset: \"m_vecOrigin\"!");
	}

	g_ownerEntity = FindSendPropInfo("CBaseCombatWeapon", "m_hOwnerEntity");
	if (g_ownerEntity == -1) {
		SetFailState("Failed to obtain offset: \"m_hOwnerEntity\"!");
	}

	LoadTranslations("csgo_weapon_fists.phrases");
	g_cookieWeaponFists = RegClientCookie("csgo_weapon_fists", "CSGO Weapon Fists", CookieAccess_Private);
	SetCookieMenuItem(WfCookieMenuHandler, 0, "CSGO Weapon Fists");

	(mp_drop_knife_enable = FindConVar("mp_drop_knife_enable")).AddChangeHook(OnCvarChanged);
	OnCvarChanged(mp_drop_knife_enable, NULL_STRING, NULL_STRING);
	HookEvent("item_equip", Event_ItemEquip); 
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (convar == mp_drop_knife_enable && StringToInt(newValue) <= 0) {
		convar.IntValue = 1; 
	}
}

public void WfCookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int iMaxlen) {
	switch (action) {
		case CookieMenuAction_DisplayOption: {
			Format(buffer, iMaxlen, "%T", g_isForceKnifeInSpawn[client] ? "Off Get knife spawn" : "On Get knife spawn", client);
		
		}
		case CookieMenuAction_SelectOption: {
			g_isForceKnifeInSpawn[client] = !g_isForceKnifeInSpawn[client];
			SetClientCookie(client, g_cookieWeaponFists, g_isForceKnifeInSpawn[client] ? "1" : "0");
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public void OnClientCookiesCached(int client) {
	char buffer[2];
	GetClientCookie(client, g_cookieWeaponFists, buffer, sizeof buffer);
	g_isForceKnifeInSpawn[client] = buffer[0] ? !!StringToInt(buffer) : false;
}

public Action Event_ItemEquip(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client)) {
		int maxSpeed = FindDataMapInfo(client, "m_flMaxspeed");
		if (maxSpeed <= 0) {
			return Plugin_Continue;
		}

		char weaponName[32];
		event.GetString("item", weaponName, sizeof weaponName);
		if (StrEqual(weaponName,"fists")) {
			SetEntData(client, maxSpeed, 250.0, 4, true);
		} else {
			SetEntData(client, maxSpeed, 260.0, 4, true);	
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && g_isForceKnifeInSpawn[client]) {
		int weaponSlot = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
		if (weaponSlot != -1 && IsValidEntity(weaponSlot) && GetEntProp(weaponSlot, Prop_Send, "m_iItemDefinitionIndex") == 69) {
			RemovePlayerItem(client, weaponSlot);
			RemoveEdict(weaponSlot);
			GivePlayerItem(client, "weapon_knife");
		}
	}
	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon) {
	if (IsValidClient(client) && IsPlayerAlive(client) && IsValidEntity(weapon) && IsWeaponKnife(weapon)) {
		int weaponSlot = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
		if (weaponSlot != -1 && IsValidEntity(weaponSlot) && GetEntProp(weaponSlot, Prop_Send, "m_iItemDefinitionIndex") == 69) {
			RemovePlayerItem(client, weaponSlot);
			RemoveEdict(weaponSlot);
			EquipPlayerWeapon(client, weapon);
		}
	}
	return Plugin_Continue;
}

public Action CS_OnCSWeaponDrop(int client, int weapon) {
	if (IsValidClient(client) && IsPlayerAlive(client) && IsWeaponKnife(weapon))
		RequestFrame(RequestOnCSWeaponDrop, GetClientSerial(client));
	return Plugin_Continue;
}

public void RequestOnCSWeaponDrop(any serial) {
	int client = GetClientFromSerial(serial);
	int ent = CreateEntityByName("weapon_fists");
	if (ent != -1 && IsValidEntity(ent) && IsValidClient(client)) {
		SetEntDataEnt2(ent, g_ownerEntity, client);
		DispatchSpawn(ent);
		EquipPlayerWeapon(client, ent);
	}
}

stock bool IsWeaponKnife(int weapon) {
	char class[8];
	GetEntityNetClass(weapon, class, sizeof class);
	return strncmp(class, "CKnife", 6) == 0;
}

stock bool IsValidClient(int client) {
	return 0 < client && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}