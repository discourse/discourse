import { run } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
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

@disableImplicitInjections
export default class ScreenTrack extends Service {
  @service appEvents;
  @service currentUser;
  @service keyValueStore;
  @service session;
  @service siteSettings;
  @service topicTrackingState;

  _ajaxFailures = 0;
  _consolidatedTimings = [];
  _lastTick = null;
  _lastScrolled = null;
  _lastFlush = 0;
  _timings = new Map();
  _totalTimings = new Map();
  _topicTime = 0;
  _onscreen = null;
  _readOnscreen = null;
  _readPosts = new Set();
  _inProgress = false;

  constructor() {
    super(...arguments);
    this.reset();
  }

  start(topicId, topicController) {
    if (this._topicId && this._topicId !== topicId) {
      this.tick();
      this.flush();
    }

    this.reset();

    // Create an interval timer if we don't have one.
    if (!this._interval) {
      this._interval = setInterval(() => {
        run(() => this.tick());
      }, 1000);
      window.addEventListener("scroll", this.scrolled);
    }

    this._topicId = topicId;
    this._topicController = topicController;
  }

  stop() {
    // already stopped no need to "extra stop"
    if (!this._topicId) {
      return;
    }

    window.removeEventListener("scroll", this.scrolled);

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
    this._timings.clear();
    this._totalTimings.clear();
    this._topicTime = 0;
    this._onscreen = null;
    this._readOnscreen = null;
    this._readPosts.clear();
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
    const foundIndex = this._consolidatedTimings.findIndex(
      (elem) => elem.topicId === topicId
    );

    if (foundIndex > -1) {
      const found = this._consolidatedTimings[foundIndex];
      const lastIndex = this._consolidatedTimings.length - 1;

      if (foundIndex !== lastIndex) {
        const last = this._consolidatedTimings[lastIndex];
        this._consolidatedTimings[lastIndex] = found;
        this._consolidatedTimings[lastIndex - 1] = last;
      }

      Object.keys(found.timings).forEach((id) => {
        if (timings[id]) {
          found.timings[id] += timings[id];
        }
      });

      found.topicTime += topicTime;
      found.timings = { ...timings, ...found.timings };
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

  async sendNextConsolidatedTiming() {
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

    const { timings, topicTime, topicId } = this._consolidatedTimings.pop();
    const data = {
      timings,
      topic_time: topicTime,
      topic_id: topicId,
    };

    this._inProgress = true;

    try {
      await ajax("/topics/timings", {
        data,
        type: "POST",
        headers: {
          "X-SILENCE-LOGGER": "true",
          "Discourse-Background": "true",
        },
      });

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this._ajaxFailures = 0;
      if (this._topicController) {
        const postNumbers = Object.keys(timings).map((v) => parseInt(v, 10));
        this._topicController.readPosts(topicId, postNumbers);

        const cachedHighestRead = this.highestReadFromCache(topicId);
        if (cachedHighestRead && cachedHighestRead <= postNumbers.lastObject) {
          resetHighestReadCache(topicId);
        }
      }

      this.appEvents.trigger("topic:timings-sent", data);
    } catch (e) {
      if (e.jqXHR && ALLOWED_AJAX_FAILURES.includes(e.jqXHR.status)) {
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
    } finally {
      this._inProgress = false;
      this._lastFlush = 0;
    }
  }

  flush() {
    const newTimings = {};

    for (const [postNumber, time] of this._timings) {
      if (!this._totalTimings.has(postNumber)) {
        this._totalTimings.set(postNumber, 0);
      }

      const totalTiming = this._totalTimings.get(postNumber);
      if (time > 0 && totalTiming < MAX_TRACKING_TIME) {
        this._totalTimings.set(postNumber, totalTiming + time);
        newTimings[postNumber] = time;
      }

      this._timings.set(postNumber, 0);
    }

    const topicId = parseInt(this._topicId, 10);

    // Workaround to avoid ignored posts being "stuck unread"
    const stream = this._topicController?.get("model.postStream");
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

    const highestSeen = Object.keys(newTimings)
      .map((postNumber) => parseInt(postNumber, 10))
      .reduce((a, b) => Math.max(a, b), 0);

    const highestSeenByTopic = this.session.get("highestSeenByTopic");
    if ((highestSeenByTopic[topicId] || 0) < highestSeen) {
      highestSeenByTopic[topicId] = highestSeen;
    }

    this.topicTrackingState.updateSeen(topicId, highestSeen);

    if (highestSeen > 0) {
      if (this.currentUser) {
        this.consolidateTimings(newTimings, this._topicTime, topicId);

        if (!isTesting()) {
          this.sendNextConsolidatedTiming();
        }
      } else if (this._anonCallback) {
        // Save total time
        const existingTime = this.keyValueStore.getInt("anon-topic-time");
        this.keyValueStore.setItem(
          "anon-topic-time",
          existingTime + this._topicTime
        );

        // Save unique topic IDs up to a max
        let topicIds = this.keyValueStore.get("anon-topic-ids");
        if (topicIds) {
          topicIds = topicIds.split(",").map((e) => parseInt(e, 10));
        } else {
          topicIds = [];
        }

        if (
          !topicIds.includes(topicId) &&
          topicIds.length < ANON_MAX_TOPIC_IDS
        ) {
          topicIds.push(topicId);
          this.keyValueStore.setItem("anon-topic-ids", topicIds.join(","));
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

    const nextFlush = this.siteSettings.flush_timings_secs * 1000;

    const rush = [...this._timings.entries()].some(([postNumber, timing]) => {
      return (
        timing > 0 &&
        !this._totalTimings.get(postNumber) &&
        !this._readPosts.has(postNumber)
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

      this._onscreen?.forEach((postNumber) =>
        this._timings.set(
          postNumber,
          (this._timings.get(postNumber) ?? 0) + diff
        )
      );

      this._readOnscreen?.forEach((postNumber) => {
        this._readPosts.add(postNumber);
      });
    }
  }
}
