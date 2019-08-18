#include <sourcemod>
#include <sdkhooks>
#include <sdktools_stringtables>

#pragma semicolon 1
#pragma newdecls required

ConVar cHp;
ConVar cSpeed;
ConVar cSound;
ConVar cDamage;
ConVar cRadius;

int g_iHP;
float g_iDamage;
float g_iSpeed;
float g_iRadius;
char g_iSound[PLATFORM_MAX_PATH];

bool g_bRage[MAXPLAYERS + 1] = false;

public Plugin myinfo = 
{
	name = "Rage",
	author = "Jon4ik (https://steamcommunity.com/id/jon4ik/)",
	description = "При определенном количестве оставшегося HP вы входите в режим \"Ярости\"",
	version = "1.0",
	url	= "https://steamcommunity.com/id/jon4ik/"
};

public void OnPluginStart()
{	
	(cHp = CreateConVar("sm_rage_hp", "15", "Количество HP для активациии Ярости", FCVAR_NOTIFY, true, 2.0, true, 99.0)).AddChangeHook(CVarChanged);
	g_iHP = cHp.IntValue;
	
	(cSpeed = CreateConVar("sm_rage_speed", "2", "% увеличения скорость передвижения игрока при активации Ярости", FCVAR_NOTIFY, false)).AddChangeHook(CVarChanged);
	g_iSpeed = 1.0 + float(cSpeed.IntValue) / 100.0;
	
	(cDamage = CreateConVar("sm_rage_damage", "5", "% увеличения урона при активации Ярости", FCVAR_NOTIFY,false)).AddChangeHook(CVarChanged);
	g_iDamage = 1.0 + float(cDamage.IntValue) / 100.0;
		
	(cSound = CreateConVar("sm_rage_sound", "Rage/rage.mp3", "Звук для воспроизведения игрокам при активации Ярости", FCVAR_NOTIFY, false)).AddChangeHook(CVarChanged);
	cSound.GetString(g_iSound, sizeof(g_iSound));
	
	(cRadius = CreateConVar("sm_rage_sound_radius", "120.0", "Радиус в котором будет проигран звук", FCVAR_NOTIFY,false)).AddChangeHook(CVarChanged);
	g_iRadius = cRadius.FloatValue;
		
	HookEvent("player_spawn", EV_SPAWN);
}

public void CVarChanged(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	if (CVar == cHp) 
    { 
    	g_iHP = CVar.IntValue;
    }
	else if (CVar == cSpeed) 
    { 
    	g_iSpeed = 1.0 + float(cSpeed.IntValue) / 100.0;
    }
	else if (CVar == cDamage) 
    { 
    	g_iDamage = 1.0 + float(cDamage.IntValue) / 100.0;
    }
	else if (CVar == cRadius) 
    { 
    	g_iRadius = cRadius.FloatValue;
    }
	else if (CVar == cSound) 
    { 
    	cSound.GetString(g_iSound, sizeof(g_iSound));
    }
}

public void OnMapStart()
{
	char sSoundPath[PLATFORM_MAX_PATH];
	if(!g_iSound[0]) return;
	FormatEx(sSoundPath, sizeof(sSoundPath), "sound/%s", g_iSound);
	if(FileExists(sSoundPath)) AddFileToDownloadsTable(sSoundPath);
	else
	{
		sSoundPath[0] = 0;
		return;
	}
	
	FormatEx(g_iSound, sizeof(g_iSound), "%s", g_iSound);
	PrecacheSound(g_iSound, true);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
}

public void OnClientDisconnect(int client)
{
	if(g_bRage[client]) g_bRage[client] = false;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);   
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamage_Post);
}

public Action EV_SPAWN(Event hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(g_bRage[client]) g_bRage[client] = false;
}
public void OnTakeDamage_Post(int client, int attacker, int inflictor, float damage, int damagetype)
{			
	if (!IsValideClient(client) || !IsValideClient(attacker)) return;
	
	if(client != attacker && !g_bRage[client])
	{
		if(GetClientHealth(client) <= g_iHP && GetClientHealth(client) > 1)
		{
			g_bRage[client] = true;
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_iSpeed);
			SetEntityRenderColor(client, 255, 0, 0, 200);
			
			if(g_iSound[0])
			{
				float fOrigin[3];
				GetClientAbsOrigin(client, fOrigin);
				PlaySoundRadius(fOrigin);
			}
		}
	}
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{		
	if (!IsValideClient(client) || !IsValideClient(attacker)) return Plugin_Handled;
	
	static float fSourceDamage;
	fSourceDamage = damage;
	
	if (g_bRage[attacker] && client != attacker)
	{
		fSourceDamage *= g_iDamage;
		
		if(fSourceDamage != damage)
		{
			damage = fSourceDamage;
			
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

void PlaySoundRadius(const float center[3])
{
    float position[3];
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsValideClient(i))
        {
            GetClientAbsOrigin(i, position);
            if (GetVectorDistance(center, position) <= g_iRadius) ClientCommand(i, "playgamesound \"%s\"", g_iSound);
        }
    }
}

bool IsValideClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)) ? true : false;
} 