net = require 'net'
util = require 'util'
EventEmitter = (require 'events').EventEmitter
JsonLineProtocol = (require 'json-line-protocol').JsonLineProtocol

CRLF = '\r\n'

# Chat server client.
# - Emits 'protocol-error' (error, line) on protocol error
# - Emits 'server-error' (error) on server-side runtime error
# - Emits 'client-error' (error) when the client encounters some error
# - Emits 'close' when a connection to the server is closed
# - Emits 'join' (channel_name, nick) when someone joins a channel 
#   that the client has joined
# - Emits 'part' (channel_name, nick, reason) when someone parts/leaves a channel 
#   that the client has joined
#   - reason is a string or null
# - Emits 'say' (channel_name, nick, message) when someone says something in 
#   a channel that the client has joined
# - Emits 'nick' (channel_name, old_nick, new_nick) when someone changes their
#   nickname and has joined to a channel that the client has joined

class ChatClient extends EventEmitter
  constructor: (port, host) ->
    @list_callback = null
    @info_callback = null
    @members_callbacks = {}

    @conn = net.createConnection port, host

    @conn.on 'connect', =>
      @conn.setEncoding 'utf8'
      @conn.setKeepAlive true
      @conn.setNoDelay true

    @protocol = new JsonLineProtocol

    @conn.on 'data', (data) => 
      @protocol.feed data

    @conn.on 'error', (error) =>
      @emit 'client-error', error.toString()

    @conn.on 'end', =>
      @emit 'client-error', 'connection-closed'

    @protocol.on 'error', (error, line) =>
      @emit 'protocol-error', error, line

    @protocol.on 'value', (msg) =>
      if msg.error?
        @emit 'server-error', msg.error
        return

      if msg.list?
        @list_callback? msg.list
        @list_callback = null
        return

      if msg.members?
        channel_name = msg.members
        @members_callbacks[channel_name]? msg.nicks
        delete @members_callbacks[channel_name]
        return

      if msg.info?
        @info_callback? msg.info
        @info_callback = null
        return

      if msg.join?
        @emit 'join', msg.join, msg.who
        return

      if msg.part?
        @emit 'part', msg.part, msg.who, msg.why
        return

      if msg.say?
        @emit 'say', msg.say, msg.who, msg.what
        return

      if msg.nick?
        @emit 'nick', msg.nick, msg.old_nick, msg.new_nick
        return

      throw new Error "unexpected message #{util.inspect msg}"
      return

  close: ->
    @conn.end()

  _write: (obj) ->
    json = JSON.stringify obj
    @conn.write json + CRLF if @conn.writable

  # Set or change your nickname to 'nick'.
  # Must be unique server-wide.

  nick: (nick) -> @_write {nick}

  # List all active channels that start with 'prefix'.
  # 'callback' is called back with an array of channel names.

  list_filter: (prefix, callback) ->
    @list_callback = callback
    @_write list:prefix

  # List all active channels.
  # 'callback' is called back with an array of channel names.

  list: (callback) ->
    @list_callback = callback
    @_write list:true

  # Join a channel with name 'channel'.

  join: (channel) -> @_write join:channel

  # List the members joined to channel with name 'channel'.
  # 'callback' is called back with an array of nicknames.

  members: (channel, callback) ->
    @members_callbacks[channel] = callback
    @_write members:channel

  # Say something ('what') in a channel with name 'channel' 
  # already joined.

  say: (channel, what) -> @_write say:channel, what:what

  # Part or leave a joined channel with name 'channel' for reason 'why'.

  part: (channel, why='') -> @_write part:channel, why:why

  # Get server information.
  # 'callback' is passed an object of the form {channels:int, users:int, uptime:int}
  # where 'uptime' is in seconds.

  info: (callback) ->
    @info_callback = callback
    @_write info:true

exports.connect = (port=11746, host='127.0.0.1') ->
  new ChatClient port, host
