nba = require 'nba'

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
        #{info.teamName} #{info.w}-#{info.l}
        #{info.pts}pts, #{info.ast}ast, #{info.reb}reb
      """
