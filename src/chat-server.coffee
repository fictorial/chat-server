#!/usr/bin/coffee

opt = require 'optimist'

argv = opt.options('host',      alias:'h', default:'127.0.0.1')
          .options('port',      alias:'p', default:11746)
          .options('log-level', alias:'l', default:'error')
          .options('max-input', alias:'M', default:1024*1024)
          .argv

net  = require 'net'
util = require 'util'

log  = new (require 'log') argv['log-level'], process.stderr

JsonLineProtocol = (require 'json-line-protocol').JsonLineProtocol

CRLF = '\r\n'

class Client
  constructor: (@stream) ->
    @nick = null
    @channels = {}
    @stream.setEncoding 'utf8'
    @stream.setTimeout 0
    @stream.setKeepAlive true
  join: (name) -> @channels[name] = true
  part: (name) -> delete @channels[name]

class Channel
  constructor: (@name) ->
    @clients = {}

  join: (client) ->
    unless @clients[client.nick]
      @broadcast client, {join:@name, who:client.nick}
      @clients[client.nick] = client

  part: (client, why) ->
    if @clients[client.nick]?
      @broadcast client, {part:@name, who:client.nick, why:why}
      delete @clients[client.nick]

  say: (client, what) ->
    @broadcast client, {say:@name, who:client.nick, what:what}

  change_nick: (client, old_nick, new_nick) ->
    delete @clients[old_nick]
    @clients[new_nick] = client
    @broadcast client, {nick:@name, old_nick, new_nick}

  broadcast: (sender, object) ->
    json = JSON.stringify object
    for _, client of @clients
      client.stream.write json + CRLF if client isnt sender

clients = {}
channels = {}
started_at = Date.now()

part = (client, channel_name, why) ->
  if client.channels[channel_name]?
    client.part channel_name
    channels[channel_name].part client, why ? ''
    delete channels[channel_name] if channels[channel_name].clients.length is 0
  return

drop_client = (client, why) ->
  log.info "dropping client #{client.nick ? '<no-nickname>'}: #{why}"
  client.stream.write (JSON.stringify error:why) + CRLF if client.stream.writable
  for channel_name, _ of client.channels
    part client, channel_name, why
  client.stream.destroySoon()
  delete clients[client.nick] if client.nick?
  return

handle_request = (stream) ->
  client = new Client stream
  protocol = new JsonLineProtocol argv['max-input']

  stream.on 'close', (had_error) -> drop_client client, 'quit'
  stream.on 'data', (data) -> protocol.feed data

  protocol.on 'error', (error, line) ->
    log.error "client protocol error: #{error.toString()} line:#{line}"
    drop_client client, 'protocol error'

  protocol.on 'overflow', ->
    log.error "client is flooding"
    drop_client client, 'flooding'

  protocol.on 'value', (command) ->
    if not client.nick? and not command.nick?
      drop_client client, 'set nickname first'
      return

    if command.nick?
      [old_nick, new_nick] = [client.nick, command.nick]
      if clients[new_nick]?
        stream.write (JSON.stringify error:'non-unique nickname') + CRLF
        return
      client.nick = new_nick
      clients[new_nick] = client
      if old_nick?
        for channel_name, _ of client.channels
          channels[channel_name].change_nick client, old_nick, new_nick
        delete clients[old_nick]
      return

    if command.list?
      prefix = command.list ? ''
      matches = (name for name, _ of channels when name.indexOf prefix is 0)
      stream.write (JSON.stringify list:matches) + CRLF
      return

    if command.join?
      channel_name = command.join
      unless client.channels[channel_name]?
        (channels[channel_name] or= new Channel channel_name).join client
        client.join channel_name
      return

    if command.part?
      channel_name = command.part
      part client, channel_name, command.why ? ''
      return

    if command.members?
      channel_name = command.members
      nicks = if channels[channel_name]?
        (nick for nick, _ of channels[channel_name].clients)
      else
        []
      stream.write (JSON.stringify members:channel_name, nicks:nicks) + CRLF
      return

    if command.say?
      channel_name = command.say
      unless client.channels[channel_name]?
        stream.write (JSON.stringify error:'non-members cannot chat') + CRLF
        drop_client client, 'protocol error'
        return
      message = (command.what ? '').trim()
      unless message.length > 0
        stream.write (JSON.stringify error:'blank message') + CRLF
        drop_client client, 'protocol error'
        return
      channels[channel_name].say client, message
      return

    if command.info?
      info =
        channels: (Object.keys channels).length
        users: (Object.keys clients).length
        uptime: +(Date.now() - started_at) / 1000
      stream.write (JSON.stringify info:info) + CRLF
      return

server = net.createServer handle_request
server.listen argv.port, argv.host, ->
  log.info "ready on #{argv.host}:#{argv.port}"

#handle_error = (error) ->
#  log.error error.toString()
#server.on 'error', handle_error
#process.on 'uncaughtException', handle_error

