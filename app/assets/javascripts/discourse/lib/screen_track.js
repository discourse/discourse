/**
  We use this class to track how long posts in a topic are on the screen.

  @class ScreenTrack
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/

var PAUSE_UNLESS_SCROLLED = 1000 * 60 * 3,
    MAX_TRACKING_TIME = 1000 * 60 * 6;

Discourse.ScreenTrack = Ember.Object.extend({

  init: function() {
    this.reset();
  },

  start: function(topicId, topicController) {
    var currentTopicId = this.get('topicId');
    if (currentTopicId && (currentTopicId !== topicId)) {
      this.tick();
      this.flush();
    }

    this.reset();

    // Create an interval timer if we don't have one.
    if (!this.get('interval')) {
      var self = this;
      this.set('interval', setInterval(function () {
        self.tick();
      }, 1000));

      $(window).on('scroll.screentrack', function(){self.scrolled()});
    }

    this.set('topicId', topicId);
    this.set('topicController', topicController);
  },

  stop: function() {
    if(!this.get('topicId')) {
      // already stopped no need to "extra stop"
      return;
    }
    $(window).off('scroll.screentrack');
    this.tick();
    this.flush();
    this.reset();
    this.set('topicId', null);
    this.set('topicController', null);
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
    this.setProperties({
      lastTick: new Date().getTime(),
      lastScrolled: new Date().getTime(),
      lastFlush: 0,
      cancelled: false,
      timings: {},
      totalTimings: {},
      topicTime: 0
    });
  },

  scrolled: function() {
    this.set('lastScrolled', new Date().getTime());
  },

  flush: function() {
    if (this.get('cancelled')) { return; }

    // We don't log anything unless we're logged in
    if (!Discourse.User.current()) return;

    var newTimings = {},
        totalTimings = this.get('totalTimings'),
        self = this;

    _.each(this.get('timings'), function(timing) {
      if (!totalTimings[timing.postNumber])
        totalTimings[timing.postNumber] = 0;

      if (timing.time > 0 && totalTimings[timing.postNumber] < MAX_TRACKING_TIME) {
        totalTimings[timing.postNumber] += timing.time;
        newTimings[timing.postNumber] = timing.time;
      }
      timing.time = 0;
    });

    var topicId = parseInt(this.get('topicId'), 10),
        highestSeen = 0;

    _.each(newTimings, function(time,postNumber) {
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    var highestSeenByTopic = Discourse.Session.currentProp('highestSeenByTopic');
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }

    Discourse.TopicTrackingState.current().updateSeen(topicId, highestSeen);

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
      }).then(function(){
        var controller = self.get('topicController');
        if(controller){
          var postNumbers = Object.keys(newTimings).map(function(v){
            return parseInt(v,10);
          });
          controller.readPosts(topicId, postNumbers);
        }
      });

      this.set('topicTime', 0);
    }
    this.set('lastFlush', 0);
  },

  tick: function() {

    // If the user hasn't scrolled the browser in a long time, stop tracking time read
    var sinceScrolled = new Date().getTime() - this.get('lastScrolled');
    if (sinceScrolled > PAUSE_UNLESS_SCROLLED) {
      return;
    }

    var diff = new Date().getTime() - this.get('lastTick');
    this.set('lastFlush', this.get('lastFlush') + diff);
    this.set('lastTick', new Date().getTime());

    var totalTimings = this.get('totalTimings'), timings = this.get('timings');
    var nextFlush = Discourse.SiteSettings.flush_timings_secs * 1000;

    // rush new post numbers
    var rush = _.any(_.filter(timings, function(t){return t.time>0;}), function(t){
      return !totalTimings[t.postNumber];
    });

    if (this.get('lastFlush') > nextFlush || rush) {
      this.flush();
    }

    // Don't track timings if we're not in focus
    if (!Discourse.get("hasFocus")) return;

    this.set('topicTime', this.get('topicTime') + diff);
    var docViewTop = $(window).scrollTop() + $('header').height(),
        docViewBottom = docViewTop + $(window).height();

    // TODO: Eyeline has a smarter more accurate function here. It's bad to do jQuery
    // in a model like component, so we should refactor this out later.
    _.each(this.get('timings'),function(timing,id) {
      var $element = $(id);
      if ($element.length === 1) {
        var elemTop = $element.offset().top,
            elemBottom = elemTop + $element.height();

        // If part of the element is on the screen, increase the counter
        if (((docViewTop <= elemTop && elemTop <= docViewBottom)) || ((docViewTop <= elemBottom && elemBottom <= docViewBottom))) {
          timing.time = timing.time + diff;
        }
      }
    });
  }
});


Discourse.ScreenTrack.reopenClass(Discourse.Singleton);

