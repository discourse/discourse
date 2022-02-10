import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { isTesting } from "discourse-common/config/environment";
import {
  getHighestReadCache,
  resetHighestReadCache,
  setHighestReadCache,
} from "discourse/lib/topic-list-tracker";

// We use this class to track how long posts in a topic are on the screen.
const PAUSE_UNLESS_SCROLLED = 1000 * 60 * 3;
const MAX_TRACKING_TIME = 1000 * 60 * 6;
const ANON_MAX_TOPIC_IDS = 5;

const AJAX_FAILURE_DELAYS = [5000, 10000, 20000, 40000];
const ALLOWED_AJAX_FAILURES = [405, 429, 500, 501, 502, 503, 504];

export default class ScreenTrack extends Service {
  @service appEvents;

  _consolidatedTimings = [];
  _lastTick = null;
  _lastScrolled = null;
  _lastFlush = 0;
  _timings = {};
  _totalTimings = {};
  _topicTime = 0;
  _onscreen = [];
  _readOnscreen = [];
  _readPosts = {};
  _inProgress = false;

  constructor() {
    super(...arguments);
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
      $(window).on("scroll.screentrack", this.scrolled);
    }

    this._topicId = topicId;
    this._topicController = topicController;
  }

  stop() {
    // already stopped no need to "extra stop"
    if (!this._topicId) {
      return;
    }

    $(window).off("scroll.screentrack", this.scrolled);

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

  setOnscreen(onscreen, readOnscreen) {
    this._onscreen = onscreen;
    this._readOnscreen = readOnscreen;
  }

  // Reset our timers
  reset() {
    const now = Date.now();
    this._lastTick = now;
    this._lastScrolled = now;
    this._lastFlush = 0;
    this._timings = {};
    this._totalTimings = {};
    this._topicTime = 0;
    this._onscreen = [];
    this._readOnscreen = [];
    this._readPosts = {};
    this._inProgress = false;
  }

  @bind
  scrolled() {
    this._lastScrolled = Date.now();
  }

  registerAnonCallback(cb) {
    this._anonCallback = cb;
  }

  consolidateTimings(timings, topicTime, topicId) {
    let foundIndex = this._consolidatedTimings.findIndex(
      (elem) => elem.topicId === topicId
    );

    if (foundIndex > -1) {
      let found = this._consolidatedTimings[foundIndex];

      const lastIndex = this._consolidatedTimings.length - 1;

      if (foundIndex !== lastIndex) {
        const last = this._consolidatedTimings[lastIndex];
        this._consolidatedTimings[lastIndex] = found;
        this._consolidatedTimings[lastIndex - 1] = last;
      }

      const oldTimings = found.timings;
      Object.keys(oldTimings).forEach((id) => {
        if (timings[id]) {
          oldTimings[id] += timings[id];
        }
      });
      found.topicTime += topicTime;
      found.timings = Object.assign({}, timings, found.timings);
    } else {
      this._consolidatedTimings.push({ timings, topicTime, topicId });
    }

    const highestRead = parseInt(Object.keys(timings).lastObject, 10);
    const cachedHighestRead = this.highestReadFromCache(topicId);
    if (!cachedHighestRead || cachedHighestRead < highestRead) {
      setHighestReadCache(topicId, highestRead);
    }

    return this._consolidatedTimings;
  }

  highestReadFromCache(topicId) {
    return getHighestReadCache(topicId);
  }

  sendNextConsolidatedTiming() {
    if (this._consolidatedTimings.length === 0) {
      return;
    }

    if (this._inProgress) {
      return;
    }

    if (
      this._blockSendingToServerTill &&
      this._blockSendingToServerTill > Date.now()
    ) {
      return;
    }

    this._ajaxFailures = this._ajaxFailures || 0;

    const { timings, topicTime, topicId } = this._consolidatedTimings.pop();
    const data = {
      timings,
      topic_time: topicTime,
      topic_id: topicId,
    };

    this._inProgress = true;

    ajax("/topics/timings", {
      data,
      type: "POST",
      headers: {
        "X-SILENCE-LOGGER": "true",
        "Discourse-Background": "true",
      },
    })
      .then(() => {
        this._ajaxFailures = 0;
        const topicController = this._topicController;
        if (topicController) {
          const postNumbers = Object.keys(timings).map((v) => parseInt(v, 10));
          topicController.readPosts(topicId, postNumbers);

          const cachedHighestRead = this.highestReadFromCache(topicId);
          if (
            cachedHighestRead &&
            cachedHighestRead <= postNumbers.lastObject
          ) {
            resetHighestReadCache(topicId);
          }
        }
        this.appEvents.trigger("topic:timings-sent", data);
      })
      .catch((e) => {
        if (e.jqXHR && ALLOWED_AJAX_FAILURES.indexOf(e.jqXHR.status) > -1) {
          const delay = AJAX_FAILURE_DELAYS[this._ajaxFailures];
          this._ajaxFailures += 1;

          if (delay) {
            this._blockSendingToServerTill = Date.now() + delay;
            // we did not send to the server, got to re-queue it
            this.consolidateTimings(timings, topicTime, topicId);
          }
        }

        if (window.console && window.console.warn && e.jqXHR) {
          window.console.warn(
            `Failed to update topic times for topic ${topicId} due to ${e.jqXHR.status} error`
          );
        }
      })
      .finally(() => {
        this._inProgress = false;
        this._lastFlush = 0;
      });
  }

  flush() {
    const newTimings = {};
    const totalTimings = this._totalTimings;

    const timings = this._timings;
    Object.keys(this._timings).forEach((postNumber) => {
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

    // Workaround to avoid ignored posts being "stuck unread"
    const controller = this._topicController;
    const stream = controller ? controller.get("model.postStream") : null;
    if (
      this.currentUser && // Logged in
      this.currentUser.get("ignored_users.length") && // At least 1 user is ignored
      stream && // Sanity check
      stream.hasNoFilters && // The stream is not filtered (by username or summary)
      !stream.canAppendMore && // We are at the end of the stream
      stream.posts.lastObject && // The last post exists
      stream.posts.lastObject.read && // The last post is read
      stream.gaps && // The stream has gaps
      !!stream.gaps.after[stream.posts.lastObject.id] && // Stream ends with a gap
      stream.topic.last_read_post_number !==
        stream.posts.lastObject.post_number +
          stream.get(`gaps.after.${stream.posts.lastObject.id}.length`) // The last post in the gap has not been marked read
    ) {
      newTimings[
        stream.posts.lastObject.post_number +
          stream.get(`gaps.after.${stream.posts.lastObject.id}.length`)
      ] = 1;
    }

    const newTimingsKeys = Object.keys(newTimings);
    newTimingsKeys.forEach((postNumber) => {
      highestSeen = Math.max(highestSeen, parseInt(postNumber, 10));
    });

    const highestSeenByTopic = this.session.get("highestSeenByTopic");
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }

    this.topicTrackingState.updateSeen(topicId, highestSeen);

    if (newTimingsKeys.length > 0) {
      if (this.currentUser && !isTesting()) {
        this.consolidateTimings(newTimings, this._topicTime, topicId);
        this.sendNextConsolidatedTiming();
      } else if (this._anonCallback) {
        // Anonymous viewer - save to localStorage
        const storage = this.keyValueStore;

        // Save total time
        const existingTime = storage.getInt("anon-topic-time");
        storage.setItem("anon-topic-time", existingTime + this._topicTime);

        // Save unique topic IDs up to a max
        let topicIds = storage.get("anon-topic-ids");
        if (topicIds) {
          topicIds = topicIds.split(",").map((e) => parseInt(e, 10));
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
    const now = Date.now();

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

    const rush = Object.keys(timings).some((postNumber) => {
      return (
        timings[postNumber] > 0 &&
        !totalTimings[postNumber] &&
        !this._readPosts[postNumber]
      );
    });

    if (!this._inProgress && (this._lastFlush > nextFlush || rush)) {
      this.flush();
    }

    if (!this._inProgress) {
      // handles retries so there is no situation where we are stuck with a backlog
      this.sendNextConsolidatedTiming();
    }

    if (this.session.hasFocus) {
      this._topicTime += diff;

      this._onscreen.forEach(
        (postNumber) =>
          (timings[postNumber] = (timings[postNumber] || 0) + diff)
      );

      this._readOnscreen.forEach((postNumber) => {
        this._readPosts[postNumber] = true;
      });
    }
  }
}
