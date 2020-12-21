#include <cstrike>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

int g_iOffsetOrigin, g_iOffsetWeaponParent;

ConVar mp_drop_knife_enable;

public Plugin myinfo = {
    name        = "CS:GO Weapon fists (mmcs.pro)",
    author      = "SAZONISCHE",
    version     = "1.2",
    url         = "mmcs.pro"
};

public void OnPluginStart() {
	// Plugin only for csgo
	if(GetEngineVersion() != Engine_CSGO)
		SetFailState("This plugin is for CSGO only.");

	g_iOffsetOrigin = FindSendPropInfo("CBasePlayer", "m_vecOrigin");
	if (g_iOffsetOrigin == -1)
		SetFailState("Failed to obtain offset: \"m_vecOrigin\"!");

	g_iOffsetWeaponParent = FindSendPropInfo("CBaseCombatWeapon", "m_hOwnerEntity");
	if (g_iOffsetWeaponParent == -1)
		SetFailState("Failed to obtain offset: \"m_hOwnerEntity\"!");

	(mp_drop_knife_enable = FindConVar("mp_drop_knife_enable")).AddChangeHook(OnCvarChanged);
	OnCvarChanged(mp_drop_knife_enable,NULL_STRING,NULL_STRING);
	HookEvent("item_equip", Event_ItemEquip); 
}

public void OnCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (convar == mp_drop_knife_enable && StringToInt(newValue) <= 0)
		convar.IntValue = 1; 
}

public void OnClientPutInServer(int iClient) {
	SDKHook(iClient, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action Event_ItemEquip(Event event, const char[] name, bool dontBroadcast) {
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(iClient)) {
		int m_flMaxspeed = -1;
		m_flMaxspeed = FindDataMapInfo(iClient, "m_flMaxspeed");
		if(m_flMaxspeed > 0)  {
			char sWeapon[32];
			event.GetString("item", sWeapon, sizeof sWeapon);
			if (StrEqual(sWeapon,"fists"))
				SetEntData(iClient, m_flMaxspeed, 250.0, 4, true);
			else
				SetEntData(iClient, m_flMaxspeed, 3000.0, 4, true);	
		}
	}
}

public Action OnWeaponCanUse(int iClient, int iWeapon) {
	if(IsValidClient(iClient) && IsPlayerAlive(iClient) && IsValidEntity(iWeapon) && IsWeaponKnife(iWeapon)) {
		int iWeaponSlot = GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE);
		if(iWeaponSlot != -1 && IsValidEntity(iWeaponSlot) && GetEntProp(iWeaponSlot, Prop_Send, "m_iItemDefinitionIndex") == 69) {
			RemovePlayerItem(iClient, iWeaponSlot);
			RemoveEdict(iWeaponSlot);
			EquipPlayerWeapon(iClient, iWeapon);
		}
	}
	return Plugin_Continue;
}

public Action CS_OnCSWeaponDrop(int iClient, int iWeapon) {
	if(IsValidClient(iClient) && IsPlayerAlive(iClient) && IsWeaponKnife(iWeapon))
		RequestFrame(RequestOnCSWeaponDrop, GetClientSerial(iClient));
}

public void RequestOnCSWeaponDrop(any Serial) {
	int iClient = GetClientFromSerial(Serial);
	int iEnt = CreateEntityByName("weapon_fists");
	if(iEnt != -1 && IsValidEntity(iEnt) && IsValidClient(iClient)) {
		SetEntDataEnt2(iEnt, g_iOffsetWeaponParent, iClient);
		DispatchSpawn(iEnt);
		EquipPlayerWeapon(iClient, iEnt);
		//SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
	}
}

stock bool IsWeaponKnife(int iWeapon) {
    char sClass[8];
    GetEntityNetClass(iWeapon, sClass, sizeof(sClass));
    return strncmp(sClass, "CKnife", 6) == 0;
}

stock bool IsValidClient(int iClient) {
	return 0 < iClient && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient);
}
