nba = require 'nba'
request = require 'superagent'

module.exports = (robot) ->

  robot.respond /nba player (.*)/, (res) ->
    name = res.match[1]
    playerId = nba.playerIdFromName name

    if not playerId?
      res.reply "Couldn't find player with name \"#{name}\""
      return

    nba.stats.playerInfo { playerId }, (err, data) ->
      info = data.playerHeadlineStats[0]

      res.reply """
        #{info.playerName} averages
        #{info.pts}pts, #{info.ast}ast, #{info.reb}reb
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

    getScores (err, scores) ->
      response = scores.map (game) ->
        context = if game.hasBegun then "#{game.away.score} - #{game.home.score}" else game.series
        """
          #{game.away.abbrev} - #{game.home.abbrev}
          #{game.status} | #{context}
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
