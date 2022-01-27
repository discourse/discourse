import Service from "@ember/service";
import EmberObject, { computed, defineProperty } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import {
  cancel,
  debounce,
  later,
  next,
  once,
  run,
  throttle,
} from "@ember/runloop";
import Session from "discourse/models/session";
import { Promise } from "rsvp";
import { isLegacyEmber, isTesting } from "discourse-common/config/environment";
import User from "discourse/models/user";
import userPresent, {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import { bind } from "discourse-common/utils/decorators";

const PRESENCE_INTERVAL_S = 30;
const PRESENCE_DEBOUNCE_MS = isTesting() ? 0 : 500;
const PRESENCE_THROTTLE_MS = isTesting() ? 0 : 1000;

const PRESENCE_GET_RETRY_MS = 5000;

const DEFAULT_ACTIVE_OPTIONS = {
  userUnseenTime: 60000,
  browserHiddenTime: 10000,
};

function createPromiseProxy() {
  const promiseProxy = {};
  promiseProxy.promise = new Promise((resolve, reject) => {
    promiseProxy.resolve = resolve;
    promiseProxy.reject = reject;
  });
  return promiseProxy;
}

export class PresenceChannelNotFound extends Error {}

// Instances of this class are handed out to consumers. They act as
// convenient proxies to the PresenceService and PresenceServiceState
class PresenceChannel extends EmberObject {
  init({ name, presenceService }) {
    super.init(...arguments);
    this.name = name;
    this.presenceService = presenceService;
    defineProperty(
      this,
      "_presenceState",
      readOnly(`presenceService._presenceChannelStates.${name}`)
    );

    this.set("present", false);
    this.set("subscribed", false);
  }

  // Mark the current user as 'present' in this channel
  // By default, the user will temporarily 'leave' the channel when
  // the current tab is in the background, or has no interaction for more than 60 seconds.
  // To override this behaviour, set onlyWhileActive: false
  // To specify custom thresholds, set `activeOptions`. See `lib/user-presence.js` for options.
  async enter({ onlyWhileActive = true, activeOptions = null } = {}) {
    if (onlyWhileActive && activeOptions) {
      for (const key in DEFAULT_ACTIVE_OPTIONS) {
        if (activeOptions[key] < DEFAULT_ACTIVE_OPTIONS[key]) {
          throw `${key} cannot be less than ${DEFAULT_ACTIVE_OPTIONS[key]} (given ${activeOptions[key]})`;
        }
      }
    } else if (onlyWhileActive && !activeOptions) {
      activeOptions = DEFAULT_ACTIVE_OPTIONS;
    }

    this.setProperties({ activeOptions });
    await this.presenceService._enter(this);
    this.set("present", true);
  }

  // Mark the current user as leaving this channel
  async leave() {
    await this.presenceService._leave(this);
    this.set("present", false);
  }

  async subscribe(initialData = null) {
    if (this.subscribed) {
      return;
    }
    await this.presenceService._subscribe(this, initialData);
    this.set("subscribed", true);
  }

  async unsubscribe() {
    if (!this.subscribed) {
      return;
    }
    await this.presenceService._unsubscribe(this);
    this.set("subscribed", false);
  }

  @computed("_presenceState.users", "subscribed")
  get users() {
    if (!this.subscribed) {
      return;
    }
    return this._presenceState.users;
  }

  @computed("_presenceState.count", "subscribed")
  get count() {
    if (!this.subscribed) {
      return;
    }
    return this._presenceState.count;
  }

  @computed("_presenceState.count", "subscribed")
  get countOnly() {
    if (!this.subscribed) {
      return;
    }
    return this._presenceState.countOnly;
  }
}

class PresenceChannelState extends EmberObject {
  init({ name, presenceService }) {
    super.init(...arguments);
    this.name = name;
    this.set("users", null);
    this.set("count", null);
    this.set("countOnly", null);
    this.presenceService = presenceService;
  }

  // Is this PresenceChannel object currently subscribed to updates
  // from the server.
  @computed("_subscribedCallback")
  get subscribed() {
    return !!this._subscribedCallback;
  }

  // Subscribe to server-side updates about the channel
  // Ideally, pass an initialData object with serialized PresenceChannel::State
  // data from the server (serialized via PresenceChannelStateSerializer).
  //
  // If initialData is not supplied, an AJAX request will be made for the information.
  async subscribe(initialData = null) {
    if (this.subscribed) {
      return;
    }

    if (!initialData) {
      initialData = await this.presenceService._getInitialData(this.name);
    }

    this.set("count", initialData.count);
    if (initialData.users) {
      this.set("users", initialData.users);
      this.set("countOnly", false);
    } else {
      this.set("users", null);
      this.set("countOnly", true);
    }

    this.lastSeenId = initialData.last_message_id;

    let callback = (data, global_id, message_id) =>
      run(() => this._processMessage(data, global_id, message_id));
    this.presenceService.messageBus.subscribe(
      `/presence${this.name}`,
      callback,
      this.lastSeenId
    );

    this.set("_subscribedCallback", callback);
  }

  // Stop subscribing to updates from the server about this channel
  unsubscribe() {
    if (this.subscribed) {
      this.presenceService.messageBus.unsubscribe(
        `/presence${this.name}`,
        this._subscribedCallback
      );
      this.set("_subscribedCallback", null);
      this.set("users", null);
      this.set("count", null);
    }
  }

  async _resubscribe() {
    this.unsubscribe();
    // Stored at object level for tests to hook in
    this._resubscribePromise = this.subscribe();
    await this._resubscribePromise;
    delete this._resubscribePromise;
  }

  async _processMessage(data, global_id, message_id) {
    if (message_id !== this.lastSeenId + 1) {
      // eslint-disable-next-line no-console
      console.log(
        `PresenceChannel '${
          this.name
        }' dropped message (received ${message_id}, expecting ${
          this.lastSeenId + 1
        }), resyncing...`
      );

      await this._resubscribe();
      return;
    } else {
      this.lastSeenId = message_id;
    }

    if (this.countOnly && data.count_delta !== undefined) {
      this.set("count", this.count + data.count_delta);
    } else if (
      !this.countOnly &&
      (data.entering_users || data.leaving_user_ids)
    ) {
      if (data.entering_users) {
        const users = data.entering_users.map((u) => User.create(u));
        this.users.addObjects(users);
      }
      if (data.leaving_user_ids) {
        const leavingIds = new Set(data.leaving_user_ids);
        const toRemove = this.users.filter((u) => leavingIds.has(u.id));
        this.users.removeObjects(toRemove);
      }
      this.set("count", this.users.length);
    } else {
      // Unexpected message
      await this._resubscribe();
      return;
    }
  }
}

export default class PresenceService extends Service {
  init() {
    super.init(...arguments);
    this._queuedEvents = [];
    this._presenceChannelStates = EmberObject.create();
    this._presentProxies = new Map();
    this._subscribedProxies = new Map();
    this._initialDataRequests = new Map();

    if (this.currentUser) {
      window.addEventListener("beforeunload", this._beaconLeaveAll);
      onPresenceChange({
        ...DEFAULT_ACTIVE_OPTIONS,
        callback: this._throttledUpdateServer,
      });
    }
  }

  get _presentChannels() {
    return new Set(this._presentProxies.keys());
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("beforeunload", this._beaconLeaveAll);
    removeOnPresenceChange(this._throttledUpdateServer);
  }

  // Get a PresenceChannel object representing a single channel
  getChannel(channelName) {
    return PresenceChannel.create({
      name: channelName,
      presenceService: this,
    });
  }

  _getInitialData(channelName) {
    let promiseProxy = this._initialDataRequests[channelName];
    if (!promiseProxy) {
      promiseProxy = this._initialDataRequests[
        channelName
      ] = createPromiseProxy();
    }

    once(this, this._makeInitialDataRequest);

    return promiseProxy.promise;
  }

  async _makeInitialDataRequest() {
    if (this._initialDataAjax) {
      // try again next runloop
      next(this, () => once(this, this._makeInitialDataRequest));
      return;
    }

    if (Object.keys(this._initialDataRequests).length === 0) {
      // Nothing to request
      return;
    }

    this._initialDataAjax = ajax("/presence/get", {
      data: {
        channels: Object.keys(this._initialDataRequests).slice(0, 50),
      },
    });

    let result;
    try {
      result = await this._initialDataAjax;
    } catch (e) {
      later(this, this._makeInitialDataRequest, PRESENCE_GET_RETRY_MS);
      throw e;
    } finally {
      this._initialDataAjax = null;
    }

    for (const channel in result) {
      if (!result.hasOwnProperty(channel)) {
        continue;
      }

      const state = result[channel];
      if (state) {
        this._initialDataRequests[channel].resolve(state);
      } else {
        const error = new PresenceChannelNotFound(
          `PresenceChannel '${channel}' not found`
        );
        this._initialDataRequests[channel].reject(error);
      }
      delete this._initialDataRequests[channel];
    }
  }

  _addPresent(channelProxy) {
    let present = this._presentProxies.get(channelProxy.name);
    if (!present) {
      present = new Set();
      this._presentProxies.set(channelProxy.name, present);
    }
    present.add(channelProxy);
    return present.size;
  }

  _removePresent(channelProxy) {
    let present = this._presentProxies.get(channelProxy.name);
    present?.delete(channelProxy);
    if (present?.size === 0) {
      this._presentProxies.delete(channelProxy.name);
    }
    return present?.size || 0;
  }

  _addSubscribed(channelProxy) {
    let subscribed = this._subscribedProxies.get(channelProxy.name);
    if (!subscribed) {
      subscribed = new Set();
      this._subscribedProxies.set(channelProxy.name, subscribed);
    }
    subscribed.add(channelProxy);
    return subscribed.size;
  }

  _removeSubscribed(channelProxy) {
    let subscribed = this._subscribedProxies.get(channelProxy.name);
    subscribed?.delete(channelProxy);
    if (subscribed?.size === 0) {
      this._subscribedProxies.delete(channelProxy.name);
    }
    return subscribed?.size || 0;
  }

  async _enter(channelProxy) {
    if (!this.currentUser) {
      throw "Must be logged in to enter presence channel";
    }

    const newCount = this._addPresent(channelProxy);
    if (newCount > 1) {
      return;
    }

    const promiseProxy = createPromiseProxy();

    this._queuedEvents.push({
      channel: channelProxy.name,
      type: "enter",
      promiseProxy,
    });

    this._scheduleNextUpdate();

    await promiseProxy.promise;
  }

  async _leave(channelProxy) {
    if (!this.currentUser) {
      throw "Must be logged in to leave presence channel";
    }

    const presentCount = this._removePresent(channelProxy);
    if (presentCount > 0) {
      return;
    }

    const promiseProxy = createPromiseProxy();

    this._queuedEvents.push({
      channel: channelProxy.name,
      type: "leave",
      promiseProxy,
    });

    this._scheduleNextUpdate();

    await promiseProxy.promise;
  }

  async _subscribe(channelProxy, initialData = null) {
    if (this.siteSettings.login_required && !this.currentUser) {
      throw "Presence is only available to authenticated users on login-required sites";
    }

    this._addSubscribed(channelProxy);
    const channelName = channelProxy.name;
    let state = this._presenceChannelStates[channelName];
    if (!state) {
      state = PresenceChannelState.create({
        name: channelName,
        presenceService: this,
      });
      this._presenceChannelStates.set(channelName, state);
      await state.subscribe(initialData);
    }
  }

  _unsubscribe(channelProxy) {
    const subscribedCount = this._removeSubscribed(channelProxy);
    if (subscribedCount === 0) {
      const channelName = channelProxy.name;
      this._presenceChannelStates[channelName].unsubscribe();
      this._presenceChannelStates.set(channelName, undefined);
    }
  }

  @bind
  _beaconLeaveAll() {
    if (isTesting()) {
      return;
    }
    this._dedupQueue();
    const channelsToLeave = this._queuedEvents
      .filter((e) => e.type === "leave")
      .map((e) => e.channel);

    channelsToLeave.push(...this._presentChannels);

    if (channelsToLeave.length === 0) {
      return;
    }

    const data = new FormData();
    data.append("client_id", this.messageBus.clientId);
    channelsToLeave.forEach((ch) => data.append("leave_channels[]", ch));

    data.append("authenticity_token", Session.currentProp("csrfToken"));
    navigator.sendBeacon("/presence/update", data);
  }

  _dedupQueue() {
    const deduplicated = {};
    this._queuedEvents.forEach((e) => {
      if (deduplicated[e.channel]) {
        deduplicated[e.channel].promiseProxy.resolve(e.promiseProxy.promise);
      }
      deduplicated[e.channel] = e;
    });
    this._queuedEvents = Object.values(deduplicated);
  }

  async _updateServer() {
    this._lastUpdate = new Date();
    this._updateRunning = true;

    this._cancelTimer();

    this._dedupQueue();
    const queue = this._queuedEvents;
    this._queuedEvents = [];

    try {
      const presentChannels = [];
      const channelsToLeave = queue
        .filter((e) => e.type === "leave")
        .map((e) => e.channel);

      for (const [channelName, proxies] of this._presentProxies) {
        if (
          Array.from(proxies).some((p) => {
            return !p.activeOptions || userPresent(p.activeOptions);
          })
        ) {
          presentChannels.push(channelName);
        } else {
          channelsToLeave.push(channelName);
        }
      }

      if (queue.length === 0 && presentChannels.length === 0) {
        return;
      }

      const response = await ajax("/presence/update", {
        data: {
          client_id: this.messageBus.clientId,
          present_channels: presentChannels,
          leave_channels: channelsToLeave,
        },
        type: "POST",
      });

      queue.forEach((e) => {
        if (response[e.channel] === false) {
          e.promiseProxy.reject(
            new PresenceChannelNotFound(
              `PresenceChannel '${e.channel}' not found`
            )
          );
        } else {
          e.promiseProxy.resolve();
        }
      });
    } catch (e) {
      if (e.jqXHR?.status === 403 && isTesting() && isLegacyEmber()) {
        // Legacy testing environment will remove the User.current() value before disposing of controllers/components.
        // Presence often involves making HTTP calls during disposal of components, so this can cause issues.
        // Modern Ember-CLI environment does not require this hack
        return;
      }

      // Put the failed events back in the queue for next time
      this._queuedEvents.unshift(...queue);
      if (e.jqXHR?.status === 429) {
        // Rate limited. No need to raise, we'll try again later
      } else {
        throw e;
      }
    } finally {
      this._updateRunning = false;
      this._scheduleNextUpdate();
    }
  }

  // `throttle` only allows triggering on the first **or** the last event
  // in a sequence of calls. We want both. We want the first event, to make
  // things very responsive. Then if things are happening too frequently, we
  // drop back to the last event via the regular throttle function.
  @bind
  _throttledUpdateServer() {
    if (
      !this._lastUpdate ||
      new Date() - this._lastUpdate > PRESENCE_THROTTLE_MS
    ) {
      this._updateServer();
    } else {
      throttle(this, this._updateServer, PRESENCE_THROTTLE_MS, false);
    }
  }

  _cancelTimer() {
    if (this._nextUpdateTimer) {
      cancel(this._nextUpdateTimer);
      this._nextUpdateTimer = null;
    }
  }

  _scheduleNextUpdate() {
    if (this._updateRunning) {
      return;
    } else if (this._queuedEvents.length > 0) {
      this._cancelTimer();
      debounce(this, this._throttledUpdateServer, PRESENCE_DEBOUNCE_MS);
    } else if (
      !this._nextUpdateTimer &&
      this._presentChannels.length > 0 &&
      !isTesting()
    ) {
      this._nextUpdateTimer = later(
        this,
        this._throttledUpdateServer,
        PRESENCE_INTERVAL_S * 1000
      );
    }
  }
}
