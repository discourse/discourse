/**
  We use this class to track how long posts in a topic are on the screen.

  @class ScreenTrack
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenTrack = Ember.Object.extend({

  // Don't send events if we haven't scrolled in a long time
  PAUSE_UNLESS_SCROLLED: 1000 * 60 * 3,

  // After 6 minutes stop tracking read position on post
  MAX_TRACKING_TIME: 1000 * 60 * 6,

  totalTimings: {},

  // Elements to track
  timings: {},
  topicTime: 0,
  cancelled: false,

  track: function(elementId, postNumber) {
    this.timings["#" + elementId] = {
      time: 0,
      postNumber: postNumber
    };
  },

  // Reset our timers
  reset: function() {
    this.lastTick = new Date().getTime();
    this.lastFlush = 0;
    this.cancelled = false;
  },

  // Start tracking
  start: function() {
    var _this = this;
    this.reset();
    this.lastScrolled = new Date().getTime();
    this.interval = setInterval(function() {
      return _this.tick();
    }, 1000);
  },

  // Cancel and eject any tracking we have buffered
  cancel: function() {
    this.cancelled = true;
    this.timings = {};
    this.topicTime = 0;
    clearInterval(this.interval);
    this.interval = null;
  },

  // Stop tracking and flush buffered read records
  stop: function() {
    clearInterval(this.interval);
    this.interval = null;
    return this.flush();
  },

  scrolled: function() {
    this.lastScrolled = new Date().getTime();
  },

  flush: function() {
    var highestSeenByTopic, newTimings, topicId,
      _this = this;
    if (this.cancelled) {
      return;
    }
    // We don't log anything unless we're logged in
    if (!Discourse.User.current()) return;

    newTimings = {};
    Object.values(this.timings, function(timing) {
      if (!_this.totalTimings[timing.postNumber])
        _this.totalTimings[timing.postNumber] = 0;

      if (timing.time > 0 && _this.totalTimings[timing.postNumber] < _this.MAX_TRACKING_TIME) {
        _this.totalTimings[timing.postNumber] += timing.time;
        newTimings[timing.postNumber] = timing.time;
      }
      timing.time = 0;
    });
    topicId = this.get('topic_id');

    var highestSeen = 0;
    $.each(newTimings, function(postNumber){
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    highestSeenByTopic = Discourse.get('highestSeenByTopic');
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }
    if (!Object.isEmpty(newTimings)) {
      Discourse.ajax('/topics/timings', {
        data: {
          timings: newTimings,
          topic_time: this.topicTime,
          topic_id: topicId
        },
        cache: false,
        type: 'POST',
        headers: {
          'X-SILENCE-LOGGER': 'true'
        }
      });
      this.topicTime = 0;
    }
    this.lastFlush = 0;
  },

  tick: function() {
    // If the user hasn't scrolled the browser in a long time, stop tracking time read
    var diff, docViewBottom, docViewTop, sinceScrolled,
      _this = this;
    sinceScrolled = new Date().getTime() - this.lastScrolled;
    if (sinceScrolled > this.PAUSE_UNLESS_SCROLLED) {
      this.reset();
      return;
    }
    diff = new Date().getTime() - this.lastTick;
    this.lastFlush += diff;
    this.lastTick = new Date().getTime();
    if (this.lastFlush > (Discourse.SiteSettings.flush_timings_secs * 1000)) {
      this.flush();
    }

    // Don't track timings if we're not in focus
    if (!Discourse.get("hasFocus")) return;

    this.topicTime += diff;
    docViewTop = $(window).scrollTop() + $('header').height();
    docViewBottom = docViewTop + $(window).height();

    // TODO: Eyeline has a smarter more accurate function here

    return Object.keys(this.timings, function(id) {
      var $element, elemBottom, elemTop, timing;
      $element = $(id);
      if ($element.length === 1) {
        elemTop = $element.offset().top;
        elemBottom = elemTop + $element.height();

        // If part of the element is on the screen, increase the counter
        if (((docViewTop <= elemTop && elemTop <= docViewBottom)) || ((docViewTop <= elemBottom && elemBottom <= docViewBottom))) {
          timing = _this.timings[id];
          timing.time = timing.time + diff;
        }
      }
    });
  }

});
