nba = require 'nba'
request = require 'superagent'
contra = require 'contra'

module.exports = (robot) ->

  robot.respond /nba player (.*)/, (res) ->
    name = res.match[1]
    playerId = nba.playerIdFromName name

    if not playerId?
      res.reply "Couldn't find player with name \"#{name}\""
      return

    contra.concurrent [
      nba.stats.playerInfo.bind(nba.stats, { playerId }),
      nba.stats.playerProfile.bind(nba.stats, { playerId })
    ], (err, [playerInfo, playerProfile]) ->
      info = playerInfo.commonPlayerInfo[0]
      averages = playerProfile.overviewSeasonAvg[0]
      lastGame = playerProfile.gameLogs[0]

      res.reply """
        #{info.displayFirstLast}, #{info.teamName} #{info.position}
        #{info.height} #{info.weight}lbs

        Season averages
        #{averages.pts}pts, #{averages.ast}ast, #{averages.reb}reb in #{averages.min} minutes

        Last game (#{lastGame.matchup})
        #{lastGame.pts}pts, #{lastGame.ast}ast, #{lastGame.reb}reb in #{lastGame.min} minutes
      """

  robot.respond /nba team (.*)/, (res) ->
    name = res.match[1]
    teamId = nba.teamIdFromName name

    if not teamId?
      res.reply "Couldn't find team with name \"#{name}\""
      return

    nba.stats.teamStats { teamId }, (err, data) ->
      info = data[0]

      res.reply """
        #{info.teamName} (#{info.w}-#{info.l})
        #{info.pts}pts, #{info.ast}ast, #{info.reb}reb
      """

  robot.respond /nba scores/, (res) ->

    getContext = (game) ->
      if game.hasBegun
        return "#{game.away.score} - #{game.home.score}"
      else if game.series
        return game.series
      else
        return "First matchup"

    getScores (err, scores) ->
      response = scores.map (game) ->
        """
          #{game.away.name} at #{game.home.name}
          #{game.status} | #{getContext(game)}
        """
      res.reply response.join('\n\n')

currentScoresUrl = 'http://data.nba.com/data/5s/v2015/json/mobile_teams/nba/2015/scores/00_todays_scores.json'
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
        status: buildStatus(game)
        away: buildTeam(game.v),
        home: buildTeam(game.h),
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
  else if not game.cl?
    return game.stt
  else
    return "#{game.cl} - #{game.stt}"
