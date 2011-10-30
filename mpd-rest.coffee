mpdSocket = require 'mpdsocket'
express = require 'express'

module.exports = (host='localhost', port=6600) ->
  mpd = new mpdSocket host, port
  app = express.createServer()

  app.use express.bodyParser()
  app.use (req, res, next) ->
    if req.method is 'PUT' and not req.is 'json'
      res.send "I only accept content-type: application/json", 400
    else
      next()


  # Generates get and put API functions
  api = (uri, actions) ->
    for method, act of actions
      do (method, act) ->      
        if typeof act is 'string'
          act = new Function act, "return #{act};"
      
        if typeof act is 'function'
          [_act, act] = [act, {}]

          if method is 'get'
            cmd = _act.toString().match(/^function \w*\((.*?)\)/)[1]

            act.to = -> cmd
            act.from = _act

          else
            act.to = _act
            act.from = (x) -> x
        
        makeReq method, uri, act.to, act.from
        
  makeReq = (method, uri, to, from=(x)->x) ->
    app[method] uri, (req, res) ->
      res.contentType 'json'
      cmd = to req
      #console.log "cmd is", cmd
      mpd.send cmd, (err, result) ->
        if err
          res.send err, 400
        else 
          res.send JSON.stringify from result
      


  api '/time',
    get: (status) -> status.elapsed or 0
    put: (req) -> "seek 0 " + Math.floor req.body

  api '/playing',
    get: (status) -> status.state == 'play'
    put: (req) -> if req.body then "play" else "pause 1"

  api '/repeat',
    get: (status) -> status.repeat == "1"
    put: (req) -> if req.body then "repeat 1" else "repeat 0"

  api '/random',
    get: (status) -> status.random == "1"
    put: (req) -> if req.body then "random 1" else "random 0"

  api '/songs',
    get: "playlistinfo"
    post: (req) ->
      "addid \"#{req.body.file}\" #{req.body.Pos or ''}"
    delete: (req) -> "clear"

  api '/stats', get: "stats"

  api '/songs/current',
    get: "currentsong"
    post: (req) ->
      id = req.body.Id
      if id?
        if id == 'next'
          "next"
        else if id == 'prev'
          "previous"
        else
          "playid #{id}"

  api '/songs/:id',
    get:
      to: (req) -> "playlistid #{req.param 'id'}"
    
    delete: (req) -> "deleteid #{req.param 'id'}"

    post: (req) ->
      if req.body.Pos?
        "moveid #{req.param 'id'} #{req.body.Pos}"
        

  api '/db/search',
    get:
      to: (req) -> "search #{req.param 'type', 'any'} \"#{req.param 'q', ''}\""
  
  app


