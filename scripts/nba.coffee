nba = require 'nba'
request = require 'superagent'

module.exports = (robot) ->

  robot.respond /nba player (.*)/, (res) ->
    name = res.match[1]
    PlayerID = nba.playerIdFromName name

    if not PlayerID?
      res.reply "Couldn't find player with name \"#{name}\""
      return

    Promise.all([
      nba.stats.playerInfo({ PlayerID }),
      nba.stats.playerProfile({ PlayerID })
    ]).then ([playerInfo, playerProfile]) ->
      info = playerInfo.commonPlayerInfo[0]
      averages = playerProfile.overviewSeasonAvg[0]
      lastGame = playerProfile.gameLogs[0]

      res.reply """
        #{info.displayFirstLast}, #{info.teamName} #{info.position}
        #{info.height} #{info.weight}lbs

        Season averages
        #{displayGameData(averages)}

        Last game (#{lastGame.matchup})
        #{displayGameData(lastGame)}
      """
    , (reason) ->
      res.reply """
        Error getting player stats
        #{JSON.stringify reason, null, 2}
      """

  robot.respond /nba team (.*)/, (res) ->
    name = res.match[1]
    TeamId = nba.teamIdFromName name

    if not TeamId?
      res.reply "Couldn't find team with name \"#{name}\""
      return

    nba.stats.teamStats({ TeamId }).then (data) ->
      info = data[0]

      res.reply """
        #{info.teamName} (#{info.w}-#{info.l})
        #{info.pts}pts, #{info.ast}ast, #{info.reb}reb
      """
    , (reason) ->
      res.reply """
        Error getting team stats
        #{JSON.stringify reason, null, 2}
      """

  robot.respond /nba scores/, (res) ->

    getContext = (game) ->
      if game.hasBegun
        return "#{game.away.score} - #{game.home.score}"
      else if game.series
        return game.series
      else
        return "First matchup"

    getTeamNames = (game) ->
      { away, home } = game
      if game.isOver
        homeTeamWon = home.score > away.score
        if homeTeamWon
          "#{away.name} at *#{home.name}*"
        else
          "*#{away.name}* at #{home.name}"

      else
        "#{away.name} at #{home.name}"

    getScores (err, scores) ->
      response = scores.map (game) ->
        """
          #{getTeamNames(game)}
          #{game.status} | #{getContext(game)}
        """
      res.reply response.join('\n\n')

  robot.respond /nba standing(s?)/, (res) ->
    displayTeam = (t) ->
      behind = if t.gamesBehind is '-' then '' else "(#{t.gamesBehind}GB)"
      """
        ##{t.seed} #{t.name} #{behind}
        #{t.wins}W - #{t.losses}L (#{t.winPercent})
      """

    getConferenceStandings (err, conferences) ->
      response = conferences.map (conference) ->
        """
          #{conference.name}

          #{conference.teams.map(displayTeam).join('\n\n')}
        """
      res.reply response.join('\n\n\n')

displayGameData = (game) ->
  "#{game.pts}pts, #{game.ast}ast, #{game.reb}reb in #{game.min} minutes"

currentScoresUrl = 'http://data.nba.com/data/5s/v2015/json/mobile_teams/nba/2016/scores/00_todays_scores.json'
requestCurrentScores = (cb) ->
  request
    .get(currentScoresUrl)
    .end (err, res) ->
      cb err, JSON.parse(res.text)

getScores = (cb) ->
  requestCurrentScores (err, data) ->
    return cb(err, null) if err?

    formattedScores = data.gs.g.map (game) ->
      {
        hasBegun: !!game.cl
        isOver: game.stt is 'Final'
        status: buildStatus(game)
        away: buildTeam(game.v)
        home: buildTeam(game.h)
        series: game.lm.seri
      }

    cb null, formattedScores

buildTeam = (team) ->
  {
    id: team.tid,
    city: team.tc,
    name: team.tn,
    abbrev: team.ta,
    score: team.s
  }

buildStatus = (game) ->
  if game.stt is 'Final'
    return 'Final'
  else if not game.cl? or game.cl is '00:00.0'
    return game.stt
  else
    return "#{game.cl} - #{game.stt}"

conferenceStandingsUrl = 'http://cdn.espn.go.com/core/nba/standings?xhr=1&device=desktop'
requestConferenceStandings = (cb) ->
  request
    .get(conferenceStandingsUrl)
    .end (err, res) ->
      cb err, JSON.parse(res.text)

getConferenceStandings = (cb) ->
  requestConferenceStandings (err, data) ->
    return cb(err, null) if err?

    conferences = data.content.standings.groups.map buildConference
    cb null, conferences

buildConference = (data) ->
  {
    name: data.name,
    teams: data.standings.entries.map buildTeamStanding
  }

buildTeamStanding = (data) ->
  getStat = (stats, name) ->
    matches = stats.filter (stat) -> stat.name is name
    return matches[0].displayValue

  { team, stats } = data

  return {
    name: team.name,
    city: team.location,
    seed: team.seed,
    abbrev: team.abbreviation,
    wins: getStat(stats, 'wins'),
    losses: getStat(stats, 'losses'),
    winPercent: getStat(stats, 'winPercent'),
    gamesBehind: getStat(stats, 'gamesBehind')
  }
