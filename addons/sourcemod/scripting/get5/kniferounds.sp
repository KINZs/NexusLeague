char voteMode[128];

public Action StartKnifeRound(Handle timer) {
  g_HasKnifeRoundStarted = false;
  g_PendingSideSwap = false;

  Get5_MessageToAll("%t", "KnifeIn5SecInfoMessage");

  CreateTimer(8.0, Timer_AnnounceKnife);
  return Plugin_Handled;
}

public Action Timer_AnnounceKnife(Handle timer) {
  for (int i = 0; i < 3; i++) {
    Get5_MessageToAll("%t", "KnifeInfoMessage");
  }

  g_HasKnifeRoundStarted = true;
  EventLogger_KnifeStart();
  return Plugin_Handled;
}

static void PerformSideSwap(bool swap) {
  if (swap) {
    int tmp = g_TeamSide[MatchTeam_Team2];
    g_TeamSide[MatchTeam_Team2] = g_TeamSide[MatchTeam_Team1];
    g_TeamSide[MatchTeam_Team1] = tmp;

    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        int team = GetClientTeam(i);
        if (team == CS_TEAM_T) {
          SwitchPlayerTeam(i, CS_TEAM_CT);
        } else if (team == CS_TEAM_CT) {
          SwitchPlayerTeam(i, CS_TEAM_T);
        } else if (IsClientCoaching(i)) {
          int correctTeam = MatchTeamToCSTeam(GetClientMatchTeam(i));
          UpdateCoachTarget(i, correctTeam);
        }
      }
    }
  } else {
    g_TeamSide[MatchTeam_Team1] = TEAM1_STARTING_SIDE;
    g_TeamSide[MatchTeam_Team2] = TEAM2_STARTING_SIDE;
  }

  g_TeamStartingSide[MatchTeam_Team1] = g_TeamSide[MatchTeam_Team1];
  g_TeamStartingSide[MatchTeam_Team2] = g_TeamSide[MatchTeam_Team2];
  SetMatchTeamCvars();
}

public void EndKnifeRound(bool swap) {
  PerformSideSwap(swap);
  EventLogger_KnifeWon(g_KnifeWinnerTeam, swap);
  ChangeState(Get5State_GoingLive);
  CreateTimer(3.0, StartGoingLive, _, TIMER_FLAG_NO_MAPCHANGE);
}

static bool AwaitingKnifeDecision(int client) {
  bool waiting = g_GameState == Get5State_WaitingForKnifeRoundDecision;
  bool onWinningTeam = IsPlayer(client) && GetClientMatchTeam(client) == g_KnifeWinnerTeam;
  bool admin = (client == 0);
  return waiting && (onWinningTeam || admin);
}

/** ESEA Vote Commands **/
void HandleVotes() {

  int winner = Get5_MatchTeamToCSTeam(g_KnifeWinnerTeam);

  float votePercentCTs = FloatDiv(float(g_iVoteCTs), float(GetNumHumansOnTeam(winner)));
  float votePercentTs = FloatDiv(float(g_iVoteTs), float(GetNumHumansOnTeam(winner)));

  float limit = g_VoteThresholdCvar.FloatValue;

  if (FloatCompare(votePercentCTs, limit) >= 0)
  {
    if (winner == CS_TEAM_CT)
    {
      Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage", g_FormattedTeamNames[g_KnifeWinnerTeam]);
      EndKnifeRound(false);
      delete g_bSideVoteTimer;
    } 
    else if (winner == CS_TEAM_T)
    {
      Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage", g_FormattedTeamNames[g_KnifeWinnerTeam]);
      EndKnifeRound(true);
      delete g_bSideVoteTimer;
    }
  }
  
  else if (FloatCompare(votePercentTs, limit) >= 0)
  {
    if (winner == CS_TEAM_T) 
    {
      Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage", g_FormattedTeamNames[g_KnifeWinnerTeam]);
      EndKnifeRound(false);
      delete g_bSideVoteTimer;
    } 
    else if (winner == CS_TEAM_CT) 
    {
      Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage", g_FormattedTeamNames[g_KnifeWinnerTeam]);
      EndKnifeRound(true);
      delete g_bSideVoteTimer;
    }
  }

  if (Get5_GetGameState() == Get5State_GoingLive)
  {
    g_bVoteStart = false;
    g_iVoteCTs = 0;
    g_iVoteTs = 0;

    for (int i = 1; i <= MaxClients; i++) {
      g_bPlayerCanVote[i] = true;
    }
  }
}

public Action Command_VoteCT(int client, int args) {
  GetConVarString(g_voteModeCvar, voteMode, sizeof(voteMode));
  if (StrEqual(voteMode, "ESEA", false)) 
  {
    if (AwaitingKnifeDecision(client)) 
    {
      if (g_bVoteStart && g_bPlayerCanVote[client]) 
      {
        g_bPlayerCanVote[client] = false;
        g_iVoteCTs++;
        Get5_Message(client, "%t", "TeamVoteCT");
        HandleVotes();

        return Plugin_Handled;
        
      }

      if (g_bVoteStart && !g_bPlayerCanVote[client]) 
      {
        Get5_Message(client, "%t", "VoteHasAlreadyCasted");
      } 
      else 
      {
        return Plugin_Stop;
      }

    } 

    else 
    {
      return Plugin_Stop;
    }

  } 
  else 
  {
    return Plugin_Stop;
  }

  return Plugin_Handled;
}


public Action Command_VoteT(int client, int args) {
  GetConVarString(g_voteModeCvar, voteMode, sizeof(voteMode));
  if (StrEqual(voteMode, "ESEA", false)) 
  {
    if (AwaitingKnifeDecision(client)) 
    {
      if (g_bVoteStart && g_bPlayerCanVote[client]) 
      {
        g_bPlayerCanVote[client] = false;
        g_iVoteTs++;
        Get5_Message(client, "%t", "TeamVoteT");
        HandleVotes();
      }
        return Plugin_Handled;
    }
    if (g_bVoteStart && !g_bPlayerCanVote[client]) 
      Get5_Message(client, "%t", "VoteHasAlreadyCasted");
    else 
      return Plugin_Stop;
  }
  else
    return Plugin_Stop;
  
  return Plugin_Handled;
}

public Action Timer_VoteSide(Handle timer) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
    delete g_bSideVoteTimer;
}

/** Default Vote Commands **/
public Action Command_Stay(int client, int args) {
  GetConVarString(g_voteModeCvar, voteMode, sizeof(voteMode));
  if (StrEqual(voteMode, "ESEA", false)) {
    return Plugin_Handled;
  } else {
    if (AwaitingKnifeDecision(client)) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
    }
  }
  return Plugin_Handled;
}

public Action Command_Swap(int client, int args) {
  GetConVarString(g_voteModeCvar, voteMode, sizeof(voteMode));
  if (StrEqual(voteMode, "ESEA", false)) {
    return Plugin_Handled;
  } else {
    if (AwaitingKnifeDecision(client)) {
      EndKnifeRound(true);
      Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage",g_FormattedTeamNames[g_KnifeWinnerTeam]);
  } else if (g_GameState == Get5State_Warmup && g_InScrimMode && GetClientMatchTeam(client) == MatchTeam_Team1) {
    PerformSideSwap(true);
    }
  }
  return Plugin_Handled;
}

public Action Timer_ForceKnifeDecision(Handle timer) {
  if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamLostTimeToDecideInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
  }
}
