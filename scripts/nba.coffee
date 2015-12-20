nba = require 'nba'

module.exports = (robot) ->

  robot.respond /nba player (.*)/, (res) ->
    name = res.match[1]
    playerId = nba.playerIdFromName name

    nba.stats.playerInfo { playerId }, (err, data) ->
      info = data.playerHeadlineStats[0]

      res.reply """
        #{info.playerName} averages
        #{info.pts}pts, #{info.ast}ast, #{info.reb}reb
      """
