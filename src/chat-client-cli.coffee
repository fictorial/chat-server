#!/usr/bin/env coffee

# chat client command-line interface.

client = (require './chat-client').connect()

fatal_error_handler = (error) ->
  console.error 'fatal:', error.toString()
  client.close()
  process.exit 1

show_error_handler = (error) ->
  console.error 'error:', error.toString()

client.on 'error', show_error_handler
client.on 'server-error', show_error_handler
client.on 'protocol-error', fatal_error_handler
client.on 'client-error', fatal_error_handler

client.on 'join', (channel, who)      -> console.log "[#{channel}] * #{who} joined"
client.on 'part', (channel, who, why) -> console.log "[#{channel}] * #{who} parted (#{why})"
client.on 'say', (channel, who, what) -> console.log "[#{channel}] <#{who}> #{what}"
client.on 'nick', (channel, old_nick, new_nick) ->
  console.log "[#{channel}] * #{old_nick} is now known as #{new_nick}"

process.stdin.setEncoding 'utf8'
process.stdin.resume()
process.stdin.on 'data', (chunk) ->
  lines = chunk.split '\n'
  for line in lines
    line = line.trim()
    continue if line.length is 0
    if line.match /^\/list\s*/i
      client.list (list) -> console.log list
    else if match = line.match /^\/nick\s+(\S+)/i
      client.nick match[1]
    else if match = line.match /^\/join\s+(\S+)/i
      client.join match[1]
    else if match = line.match /^\/part\s+(\S+)/i
      client.part match[1]
    else if match = line.match /^\/members\s+(\S+)/i
      channel = match[1]
      client.members match[1], (nicks) -> console.log "#{channel}: #{nicks}"
    else if match = line.match /^\/say\s+(\S+)\s+(.+)/i
      [channel, what] = [match[1], match[2]]
      client.say channel, what
    else if match = line.match /^\/info\s*/i
      client.info (info) -> console.log info
    else
      console.log "unknown command"

process.stdin.on 'end', -> 
  console.debug 'QUITTING'
  client.close()

