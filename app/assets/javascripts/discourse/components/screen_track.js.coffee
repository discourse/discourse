# We use this class to track how long posts in a topic are on the screen.
# This could be a potentially awesome metric to keep track of.
window.Discourse.ScreenTrack = Ember.Object.extend

  # Don't send events if we haven't scrolled in a long time
  PAUSE_UNLESS_SCROLLED: 1000*60*3

  # After 6 minutes stop tracking read position on post
  MAX_TRACKING_TIME:  1000*60*6

  totalTimings: {}

  # Elements to track
  timings: {}
  topicTime: 0

  cancelled: false

  track: (elementId, postNumber) ->
    @timings["##{elementId}"] =
      time: 0
      postNumber: postNumber

  guessedSeen: (postNumber) ->
    @highestSeen = postNumber if postNumber > (@highestSeen || 0)

  # Reset our timers
  reset: ->
    @lastTick = new Date().getTime()
    @lastFlush = 0
    @cancelled = false

  # Start tracking
  start: ->
    @reset()
    @lastScrolled = new Date().getTime()
    @interval = setInterval =>
      @tick()
    , 1000

  # Cancel and eject any tracking we have buffered
  cancel: ->
    @cancelled = true
    @timings = {}
    @topicTime = 0
    clearInterval(@interval)
    @interval = null

  # Stop tracking and flush buffered read records
  stop: ->
    clearInterval(@interval)
    @interval = null
    @flush()

  scrolled: ->
    @lastScrolled = new Date().getTime()

  flush: ->

    return if @cancelled

    # We don't log anything unless we're logged in
    return unless Discourse.get('currentUser')

    newTimings = {}
    Object.values @timings, (timing) =>
      @totalTimings[timing.postNumber] ||= 0
      if timing.time > 0 and @totalTimings[timing.postNumber] < @MAX_TRACKING_TIME
        @totalTimings[timing.postNumber] += timing.time
        newTimings[timing.postNumber] = timing.time
      timing.time = 0

    topicId = @get('topic_id')

    highestSeenByTopic = Discourse.get('highestSeenByTopic')
    if (highestSeenByTopic[topicId] || 0) < @highestSeen
      highestSeenByTopic[topicId] = @highestSeen


    unless Object.isEmpty(newTimings)
      $.ajax '/topics/timings'
        data:
          timings: newTimings
          topic_time: @topicTime
          highest_seen: @highestSeen
          topic_id: topicId
        cache: false
        type: 'POST'
        headers:
          'X-SILENCE-LOGGER': 'true'
      @topicTime = 0

    @lastFlush = 0

  tick: ->

    # If the user hasn't scrolled the browser in a long time, stop tracking time read
    sinceScrolled = new Date().getTime() - @lastScrolled
    if sinceScrolled > @PAUSE_UNLESS_SCROLLED
      @reset()
      return

    diff = new Date().getTime() - @lastTick
    @lastFlush += diff
    @lastTick = new Date().getTime()

    @flush() if @lastFlush > (Discourse.SiteSettings.flush_timings_secs * 1000)

    # Don't track timings if we're not in focus
    return unless Discourse.get("hasFocus")

    @topicTime += diff

    docViewTop = $(window).scrollTop() + $('header').height()
    docViewBottom = docViewTop + $(window).height()

    Object.keys @timings, (id) =>
      $element = $(id)

      if ($element.length == 1)
        elemTop = $element.offset().top
        elemBottom = elemTop + $element.height()

        # If part of the element is on the screen, increase the counter
        if (docViewTop <= elemTop <= docViewBottom) or (docViewTop <= elemBottom <= docViewBottom)
          timing = @timings[id]
          timing.time = timing.time + diff

