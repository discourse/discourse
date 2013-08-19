/**
  We use this class to track how long posts in a topic are on the screen.

  @class ScreenTrack
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenTrack = Ember.Object.extend({

  init: function() {
    var screenTrack = this;
    this.reset();
  },

  start: function(topicId) {
    var currentTopicId = this.get('topicId');
    if (currentTopicId && (currentTopicId !== topicId)) {
      this.tick();
      this.flush();
    }

    this.reset();

    // Create an interval timer if we don't have one.
    if (!this.get('interval')) {
      var screenTrack = this;
      this.set('interval', setInterval(function () {
        screenTrack.tick();
      }, 1000));
    }

    this.set('topicId', topicId);
  },

  stop: function() {
    this.tick();
    this.flush();
    this.reset();
    this.set('topicId', null);
    if (this.get('interval')) {
      clearInterval(this.get('interval'));
      this.set('interval', null);
    }
  },

  track: function(elementId, postNumber) {
    this.get('timings')["#" + elementId] = {
      time: 0,
      postNumber: postNumber
    };
  },

  stopTracking: function(elementId) {
    delete this.get('timings')['#' + elementId];
  },

  // Reset our timers
  reset: function() {
    this.set('lastTick', new Date().getTime());
    this.set('lastScrolled', new Date().getTime());
    this.set('lastFlush', 0);
    this.set('cancelled', false);
    this.set('timings', {});
    this.set('totalTimings', {});
    this.set('topicTime', 0);
  },

  scrolled: function() {
    this.set('lastScrolled', new Date().getTime());
  },

  flush: function() {
    if (this.get('cancelled')) { return; }

    // We don't log anything unless we're logged in
    if (!Discourse.User.current()) return;

    var newTimings = {};

    // Update our total timings
    var totalTimings = this.get('totalTimings');

    _.each(this.get('timings'), function(timing,key) {
      if (!totalTimings[timing.postNumber])
        totalTimings[timing.postNumber] = 0;

      if (timing.time > 0 && totalTimings[timing.postNumber] < Discourse.ScreenTrack.MAX_TRACKING_TIME) {
        totalTimings[timing.postNumber] += timing.time;
        newTimings[timing.postNumber] = timing.time;
      }
      timing.time = 0;
    });

    var topicId = parseInt(this.get('topicId'), 10);
    var highestSeen = 0;
    _.each(newTimings, function(time,postNumber) {
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    var highestSeenByTopic = Discourse.Session.currentProp('highestSeenByTopic');
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
      Discourse.TopicTrackingState.current().updateSeen(topicId, highestSeen);
    }
    if (!$.isEmptyObject(newTimings)) {
      Discourse.ajax('/topics/timings', {
        data: {
          timings: newTimings,
          topic_time: this.get('topicTime'),
          topic_id: topicId
        },
        cache: false,
        type: 'POST',
        headers: {
          'X-SILENCE-LOGGER': 'true'
        }
      });

      this.set('topicTime', 0);
    }
    this.set('lastFlush', 0);
  },

  tick: function() {

    // If the user hasn't scrolled the browser in a long time, stop tracking time read
    var sinceScrolled = new Date().getTime() - this.get('lastScrolled');
    if (sinceScrolled > Discourse.ScreenTrack.PAUSE_UNLESS_SCROLLED) {
      this.reset();
      return;
    }

    var diff = new Date().getTime() - this.get('lastTick');
    this.set('lastFlush', this.get('lastFlush') + diff);
    this.set('lastTick', new Date().getTime());
    if (this.get('lastFlush') > (Discourse.SiteSettings.flush_timings_secs * 1000)) {
      this.flush();
    }

    // Don't track timings if we're not in focus
    if (!Discourse.get("hasFocus")) return;

    this.set('topicTime', this.get('topicTime') + diff);
    var docViewTop = $(window).scrollTop() + $('header').height();
    var docViewBottom = docViewTop + $(window).height();

    // TODO: Eyeline has a smarter more accurate function here. It's bad to do jQuery
    // in a model like component, so we should refactor this out later.
    var screenTrack = this;
    _.each(this.get('timings'),function(timing,id) {
      var $element, elemBottom, elemTop;
      $element = $(id);
      if ($element.length === 1) {
        elemTop = $element.offset().top;
        elemBottom = elemTop + $element.height();

        // If part of the element is on the screen, increase the counter
        if (((docViewTop <= elemTop && elemTop <= docViewBottom)) || ((docViewTop <= elemBottom && elemBottom <= docViewBottom))) {
          timing.time = timing.time + diff;
        }
      }
    });
  }
});


Discourse.ScreenTrack.reopenClass(Discourse.Singleton, {

  // Don't send events if we haven't scrolled in a long time
  PAUSE_UNLESS_SCROLLED: 1000 * 60 * 3,

  // After 6 minutes stop tracking read position on post
  MAX_TRACKING_TIME: 1000 * 60 * 6

});

