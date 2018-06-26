import { ajax } from "discourse/lib/ajax";
// We use this class to track how long posts in a topic are on the screen.
const PAUSE_UNLESS_SCROLLED = 1000 * 60 * 3;
const MAX_TRACKING_TIME = 1000 * 60 * 6;
const ANON_MAX_TOPIC_IDS = 5;

const getTime = () => new Date().getTime();

export default class {
  constructor(topicTrackingState, siteSettings, session, currentUser) {
    this.topicTrackingState = topicTrackingState;
    this.siteSettings = siteSettings;
    this.session = session;
    this.currentUser = currentUser;
    this.reset();
  }

  start(topicId, topicController) {
    const currentTopicId = this._topicId;
    if (currentTopicId && currentTopicId !== topicId) {
      this.tick();
      this.flush();
    }

    this.reset();

    // Create an interval timer if we don't have one.
    if (!this._interval) {
      this._interval = setInterval(() => this.tick(), 1000);
      $(window).on("scroll.screentrack", () => this.scrolled());
    }

    this._topicId = topicId;
    this._topicController = topicController;
  }

  stop() {
    // already stopped no need to "extra stop"
    if (!this._topicId) {
      return;
    }

    $(window).off("scroll.screentrack");
    this.tick();
    this.flush();
    this.reset();

    this._topicId = null;
    this._topicController = null;

    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  }

  setOnscreen(onscreen) {
    this._onscreen = onscreen;
  }

  // Reset our timers
  reset() {
    const now = getTime();
    this._lastTick = now;
    this._lastScrolled = now;
    this._lastFlush = 0;
    this._timings = {};
    this._totalTimings = {};
    this._topicTime = 0;
    this._onscreen = [];
    this._inProgress = false;
  }

  scrolled() {
    this._lastScrolled = getTime();
  }

  registerAnonCallback(cb) {
    this._anonCallback = cb;
  }

  flush() {
    const newTimings = {};
    const totalTimings = this._totalTimings;

    const timings = this._timings;
    Object.keys(this._timings).forEach(postNumber => {
      const time = timings[postNumber];
      totalTimings[postNumber] = totalTimings[postNumber] || 0;

      if (time > 0 && totalTimings[postNumber] < MAX_TRACKING_TIME) {
        totalTimings[postNumber] += time;
        newTimings[postNumber] = time;
      }
      timings[postNumber] = 0;
    });

    const topicId = parseInt(this._topicId, 10);
    let highestSeen = 0;

    Object.keys(newTimings).forEach(postNumber => {
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    const highestSeenByTopic = this.session.get("highestSeenByTopic");
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }

    this.topicTrackingState.updateSeen(topicId, highestSeen);

    if (!$.isEmptyObject(newTimings)) {
      if (this.currentUser) {
        this._inProgress = true;
        ajax("/topics/timings", {
          data: {
            timings: newTimings,
            topic_time: this._topicTime,
            topic_id: topicId
          },
          cache: false,
          type: "POST",
          headers: {
            "X-SILENCE-LOGGER": "true"
          }
        })
          .then(() => {
            const controller = this._topicController;
            if (controller) {
              const postNumbers = Object.keys(newTimings).map(v =>
                parseInt(v, 10)
              );
              controller.readPosts(topicId, postNumbers);
            }
          })
          .catch(e => {
            const error = e.jqXHR;
            if (
              error.status === 405 &&
              error.responseJSON.error_type === "read_only"
            )
              return;
          })
          .finally(() => {
            this._inProgress = false;
            this._lastFlush = 0;
          });
      } else if (this._anonCallback) {
        // Anonymous viewer - save to localStorage
        const storage = this.keyValueStore;

        // Save total time
        const existingTime = storage.getInt("anon-topic-time");
        storage.setItem("anon-topic-time", existingTime + this._topicTime);

        // Save unique topic IDs up to a max
        let topicIds = storage.get("anon-topic-ids");
        if (topicIds) {
          topicIds = topicIds.split(",").map(e => parseInt(e));
        } else {
          topicIds = [];
        }
        if (
          topicIds.indexOf(topicId) === -1 &&
          topicIds.length < ANON_MAX_TOPIC_IDS
        ) {
          topicIds.push(topicId);
          storage.setItem("anon-topic-ids", topicIds.join(","));
        }

        // Inform the observer
        this._anonCallback();

        // No need to call controller.readPosts()
      }

      this._topicTime = 0;
    }

    this._lastFlush = 0;
  }

  tick() {
    const now = new Date().getTime();

    // If the user hasn't scrolled the browser in a long time, stop tracking time read
    const sinceScrolled = now - this._lastScrolled;
    if (sinceScrolled > PAUSE_UNLESS_SCROLLED) {
      return;
    }

    const diff = now - this._lastTick;
    this._lastFlush += diff;
    this._lastTick = now;

    const totalTimings = this._totalTimings;
    const timings = this._timings;
    const nextFlush = this.siteSettings.flush_timings_secs * 1000;

    const rush = Object.keys(timings).some(postNumber => {
      return timings[postNumber] > 0 && !totalTimings[postNumber];
    });

    if (!this._inProgress && (this._lastFlush > nextFlush || rush)) {
      this.flush();
    }

    // Don't track timings if we're not in focus
    if (!Discourse.get("hasFocus")) return;

    this._topicTime += diff;

    this._onscreen.forEach(
      postNumber => (timings[postNumber] = (timings[postNumber] || 0) + diff)
    );
  }
}
