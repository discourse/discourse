window.Discourse.MessageBus = ( ->

  # http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
  uniqueId = -> 'xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'.replace /[xy]/g, (c)->
    r = Math.random()*16 | 0
    v = if c == 'x' then r else (r&0x3|0x8)
    v.toString(16)

  clientId = uniqueId()

  responseCallbacks = {}
  callbacks = []
  queue = []
  interval = null

  failCount = 0

  isHidden = ->
    if document.hidden != undefined
      document.hidden
    else if document.webkitHidden != undefined
      document.webkitHidden
    else if document.msHidden != undefined
      document.msHidden
    else if document.mozHidden != undefined
      document.mozHidden
    else
      # fallback to problamatic window.focus
      !Discourse.get('hasFocus')

  enableLongPolling: true
  callbackInterval: 60000
  maxPollInterval: (3 * 60 * 1000)
  callbacks: callbacks
  clientId: clientId

  #TODO
  stop:
    false

  # Start polling
  start: (opts={})->

    poll = =>
      if callbacks.length == 0
        setTimeout poll, 500
        return

      data = {}
      callbacks.each (c)->
        data[c.channel] = if c.last_id == undefined then -1 else c.last_id

      gotData = false

      @longPoll = $.ajax "/message-bus/#{clientId}/poll?#{if isHidden() || !@enableLongPolling then "dlp=t" else ""}",
        data: data
        cache: false
        dataType: 'json'
        type: 'POST'
        headers:
          'X-SILENCE-LOGGER': 'true'
        success: (messages) =>
          failCount = 0
          messages.each (message) =>
            gotData = true
            callbacks.each (callback) ->
              if callback.channel == message.channel
                callback.last_id = message.message_id
                callback.func(message.data)
              if message["channel"] == "/__status"
                callback.last_id = message.data[callback.channel] if message.data[callback.channel] != undefined
              return
        error:
          failCount += 1
        complete: =>
          if gotData
            setTimeout poll, 100
          else
            interval = @callbackInterval
            if failCount > 2
              interval = interval * failCount
            else if isHidden()
              # slowning down stuff a lot when hidden
              # we will need to add a lot of fine tuning here
              interval = interval * 4

            if interval > @maxPollInterval
              interval =  @maxPollInterval

            setTimeout poll, interval
          @longPoll = null
          return

    poll()
    return

  # Subscribe to a channel
  subscribe: (channel,func,lastId)->
    callbacks.push {channel:channel, func:func, last_id: lastId}
    @longPoll.abort() if @longPoll

  # Unsubscribe from a channel
  unsubscribe: (channel) ->
    # TODO proper globbing
    if channel.endsWith("*")
      channel = channel.substr(0, channel.length-1)
      glob = true
    callbacks = callbacks.filter (callback) ->
      if glob
        callback.channel.substr(0, channel.length) != channel
      else
        callback.channel != channel
    @longPoll.abort() if @longPoll
)()
