#include <sourcemod>
#include <ripext>
#include <SteamInfo>

#pragma semicolon 1
#pragma newdecls required

// Base URL
#define REQUEST_BASE_URL "http://api.steampowered.com/ISteamApps/UpToDateCheck/v0001/?appid=%s&version=%s&format=json"

enum struct VersionRequest
{
	// HTTP formatted request url string.
	char base_url[128];
	
	//=============================================//
	
	bool Init()
	{
		char AppID[11], PatchVersion[11];
		
		if (!SteamInfo_GetValue("AppID", AppID, sizeof(AppID)) || !SteamInfo_GetValue("PatchVersion", PatchVersion, sizeof(PatchVersion)))
		{
			return false;
		}
		
		Format(this.base_url, sizeof(VersionRequest::base_url), REQUEST_BASE_URL, AppID, PatchVersion);
		
		// Initialization succeeded.
		return true;
	}
	
	void Send()
	{
		(new HTTPRequest(this.base_url)).Get(VersionRequestCB);
	}
}

VersionRequest g_VersionRequest;

ConVar g_UpdateCheckInterval;

public Plugin myinfo = 
{
	name = "Auto Updater", 
	author = "KoNLiG", 
	description = "Automatic server updater for source games.", 
	version = "1.0.0", 
	url = "https://steamcommunity.com/id/KoNLiG/ || KoNLiG#6417"
};

public void OnPluginStart()
{
	// Initialize 'g_VersionRequest'
	if (!g_VersionRequest.Init())
	{
		SetFailState("Failed to properly initialize 'g_VersionRequest'");
	}
	
	// ConVars Configuration.
	g_UpdateCheckInterval = CreateConVar("autoupdater_update_check_interval", "5", "Interval for update checks. (Represented by minutes)", .hasMin = true, .min = 1.0);
	AutoExecConfig();
	
	// Every [g_UpdateCheckInterval.FloatValue * 60.0] minutes check for a server update.
	CreateTimer(g_UpdateCheckInterval.FloatValue * 60.0, Timer_UpdateCheck, .flags = TIMER_REPEAT);
}

// Attempt to perform a server update.
Action Timer_UpdateCheck(Handle timer)
{
	g_VersionRequest.Send();
	
	return Plugin_Continue;
}

void VersionRequestCB(HTTPResponse response, any value, const char[] error)
{
	if (error[0])
	{
		LogError("An error has occured: %s", error);
		return;
	}
	
	HTTPStatus response_status = response.Status;
	if (response_status != HTTPStatus_OK)
	{
		LogError("Response status != HTTPStatus_OK (HTTPStatus == %d)", response_status);
		return;
	}
	
	JSON json = response.Data;
	
	char json_str[256];
	json.ToString(json_str, sizeof(json_str), JSON_INDENT(4));
	delete json;
	
	JSONObject jsonObject = JSONObject.FromString(json_str);
	
	// Initialize the new relevant data.
	json = jsonObject.Get("response");
	json.ToString(json_str, sizeof(json_str));
	delete json;
	
	// Delete the old json object handle, and initialize the new relevant data.
	delete jsonObject;
	jsonObject = JSONObject.FromString(json_str);
	
	if (!jsonObject.GetBool("up_to_date"))
	{
		PerformServerUpdate(jsonObject.GetInt("required_version"));
	}
	
	delete jsonObject;
}

void PerformServerUpdate(int required_version)
{
	// Kick all server clients.
	for (int current_client = 1; current_client <= MaxClients; current_client++)
	{
		if (IsClientInGame(current_client))
		{
			KickClient(current_client, "Sorry for the inconvenience.\nDue to the new game update (Ver: %d) the server has been shut down", required_version);
		}
	}
	
	LogMessage("Restarting the server due to the new game update. [%d]", required_version);
	
	// Restart the server to trigger the update sequence.
	ServerCommand("_restart");
} 