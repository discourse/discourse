// We use this class to track how long posts in a topic are on the screen.

import Singleton from 'discourse/mixins/singleton';

const PAUSE_UNLESS_SCROLLED = 1000 * 60 * 3,
      MAX_TRACKING_TIME = 1000 * 60 * 6,
      ANON_MAX_TOPIC_IDS = 5;

const ScreenTrack = Ember.Object.extend({

  init() {
    this.reset();

    // TODO: Move `ScreenTrack` to injection and remove this
    this.set('topicTrackingState', Discourse.__container__.lookup('topic-tracking-state:main'));
  },

  start(topicId, topicController) {
    const currentTopicId = this.get('topicId');
    if (currentTopicId && (currentTopicId !== topicId)) {
      this.tick();
      this.flush();
    }

    this.reset();

    // Create an interval timer if we don't have one.
    if (!this.get('interval')) {
      const self = this;
      this.set('interval', setInterval(function () {
        self.tick();
      }, 1000));

      $(window).on('scroll.screentrack', function(){self.scrolled();});
    }

    this.set('topicId', topicId);
    this.set('topicController', topicController);
  },

  stop() {
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

  track(elementId, postNumber) {
    this.get('timings')["#" + elementId] = {
      time: 0,
      postNumber: postNumber
    };
  },

  stopTracking(elementId) {
    delete this.get('timings')['#' + elementId];
  },

  // Reset our timers
  reset() {
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

  scrolled() {
    this.set('lastScrolled', new Date().getTime());
  },

  flush() {
    if (this.get('cancelled')) { return; }

    const newTimings = {},
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

    const topicId = parseInt(this.get('topicId'), 10);
    let highestSeen = 0;

    _.each(newTimings, function(time,postNumber) {
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    const highestSeenByTopic = Discourse.Session.currentProp('highestSeenByTopic');
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }

    this.topicTrackingState.updateSeen(topicId, highestSeen);

    if (!$.isEmptyObject(newTimings)) {
      if (Discourse.User.current()) {
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
        }).then(function() {
          const controller = self.get('topicController');
          if (controller) {
            const postNumbers = Object.keys(newTimings).map(function(v) {
              return parseInt(v, 10);
            });
            controller.readPosts(topicId, postNumbers);
          }
        });
      } else if (this.get('anonFlushCallback')) {
        // Anonymous viewer - save to localStorage
        const storage = this.get('keyValueStore');

        // Save total time
        const existingTime = storage.getInt('anon-topic-time');
        storage.setItem('anon-topic-time', existingTime + this.get('topicTime'));

        // Save unique topic IDs up to a max
        let topicIds = storage.get('anon-topic-ids');
        if (topicIds) {
          topicIds = topicIds.split(',').map(e => parseInt(e));
        } else {
          topicIds = [];
        }
        if (topicIds.indexOf(topicId) === -1 && topicIds.length < ANON_MAX_TOPIC_IDS) {
          topicIds.push(topicId);
          storage.setItem('anon-topic-ids', topicIds.join(','));
        }

        // Inform the observer
        this.get('anonFlushCallback')();

        // No need to call controller.readPosts()
      }

      this.set('topicTime', 0);
    }
    this.set('lastFlush', 0);
  },

  tick() {

    // If the user hasn't scrolled the browser in a long time, stop tracking time read
    const sinceScrolled = new Date().getTime() - this.get('lastScrolled');
    if (sinceScrolled > PAUSE_UNLESS_SCROLLED) {
      return;
    }

    const diff = new Date().getTime() - this.get('lastTick');
    this.set('lastFlush', this.get('lastFlush') + diff);
    this.set('lastTick', new Date().getTime());

    const totalTimings = this.get('totalTimings'), timings = this.get('timings');
    const nextFlush = Discourse.SiteSettings.flush_timings_secs * 1000;

    // rush new post numbers
    const rush = _.any(_.filter(timings, function(t){return t.time>0;}), function(t){
      return !totalTimings[t.postNumber];
    });

    if (this.get('lastFlush') > nextFlush || rush) {
      this.flush();
    }

    // Don't track timings if we're not in focus
    if (!Discourse.get("hasFocus")) return;

    this.set('topicTime', this.get('topicTime') + diff);
    const docViewTop = $(window).scrollTop() + $('header').height(),
        docViewBottom = docViewTop + $(window).height();

    // TODO: Eyeline has a smarter more accurate function here. It's bad to do jQuery
    // in a model like component, so we should refactor this out later.
    _.each(this.get('timings'),function(timing,id) {
      const $element = $(id);
      if ($element.length === 1) {
        const elemTop = $element.offset().top,
            elemBottom = elemTop + $element.height();

        // If part of the element is on the screen, increase the counter
        if (((docViewTop <= elemTop && elemTop <= docViewBottom)) || ((docViewTop <= elemBottom && elemBottom <= docViewBottom))) {
          timing.time = timing.time + diff;
        }
      }
    });
  }
});


ScreenTrack.reopenClass(Singleton);
export default ScreenTrack;
