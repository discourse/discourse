import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import {
  removeAllowedTopicGroup,
  removeAllowedTopicUser,
  updateTopicNotificationLevel,
} from "discourse/data/builders/topic-details";
import { normalizeTopicDetailsPayload } from "discourse/data/normalize";
import RestCompatModel from "discourse/data/rest-compat";
import { TopicDetailsSchema } from "discourse/data/schemas/topic-details";
import {
  defineFieldForwarders,
  warpStore,
} from "discourse/data/warp-rest-model";
import User from "discourse/models/user";

export default class TopicDetails extends RestCompatModel {
  static type = "topic-details";

  // `store.createRecord("topicDetails", { id, topic, ...attrs })` entry point.
  // Extras (e.g. tests doing `topic.details = { allowed_users: [...] }`) land
  // in `#draft` until `updateFromJson` populates the cache record.
  static create({ id, topic, ...rest } = {}) {
    const td = new this(id);
    if (topic !== undefined) {
      td.topic = topic;
    }
    if (Object.keys(rest).length > 0) {
      td.#draft = rest;
    }
    return td;
  }

  @tracked loaded = false;
  topic = null;

  #topicId;
  #draft = {};

  constructor(topicId) {
    super();
    this.#topicId = topicId == null ? null : String(topicId);
  }

  // Topic's `_details` field initializer runs before Topic.id is assigned, so
  // back-fill lazily from `this.topic.id` on first access.
  #effectiveTopicId() {
    if (this.#topicId == null && this.topic?.id != null) {
      this.#topicId = String(this.topic.id);
    }
    return this.#topicId;
  }

  // `#topicId in this` is only true once `super()` has returned and our own
  // fields and private methods are installed. The base constructor fires plugin
  // `init` callbacks, which can reach `id` / `__resource` before that — and
  // touching anything private that early throws. The check has to be inline:
  // hiding it behind a private helper would trip the same trap.
  get id() {
    return #topicId in this ? this.#effectiveTopicId() : null;
  }

  // Falls back to `#draft` so attrs set via `create({...})` (or assigned
  // before `updateFromJson`) are readable/writable.
  get __resource() {
    // See `id` — nothing private is reachable until `super()` has returned.
    if (!(#topicId in this)) {
      return undefined;
    }
    const id = this.#effectiveTopicId();
    if (id != null) {
      const cached = warpStore().peekRecord({
        type: "topic-details",
        id,
      });
      if (cached) {
        return cached;
      }
    }
    return this.#draft;
  }

  // Wraps user/participant sideloads to match legacy RestModel behavior so
  // `instanceof User` and EmberObject methods keep working.
  updateFromJson(details) {
    const id = this.#effectiveTopicId();
    if (id == null || !details) {
      return;
    }
    const wrapped = { ...details };
    if (details.allowed_users) {
      wrapped.allowed_users = details.allowed_users.map((u) => User.create(u));
    }
    if (details.participants) {
      const topic = this.topic;
      wrapped.participants = details.participants.map((p) =>
        EmberObject.create({ ...p, topic })
      );
    }
    const store = warpStore();
    store.push(normalizeTopicDetailsPayload({ topicId: id, details: wrapped }));
    this._applyExtraAttributes(id);
    this.loaded = true;
  }

  updateNotifications(level) {
    const store = warpStore();
    const id = this.#effectiveTopicId();
    return store.request(updateTopicNotificationLevel(id, level)).then(() => {
      this.notification_level = level;
      this.notifications_reason_id = null;
    });
  }

  async removeAllowedGroup(group) {
    const store = warpStore();
    await store.request(
      removeAllowedTopicGroup(this.#effectiveTopicId(), group.name)
    );
    this.allowed_groups = this.allowed_groups.filter(
      (g) => g.name !== group.name
    );
  }

  async removeAllowedUser(user) {
    const username = user.username ?? user.get?.("username");
    const store = warpStore();
    await store.request(
      removeAllowedTopicUser(this.#effectiveTopicId(), username)
    );
    this.allowed_users = this.allowed_users.filter(
      (u) => u.username !== username
    );
  }
}

defineFieldForwarders(TopicDetails, TopicDetailsSchema);
