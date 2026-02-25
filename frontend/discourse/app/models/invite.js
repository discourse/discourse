import EmberObject, { computed, set } from "@ember/object";
import { isNone } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

export default class Invite extends EmberObject {
  static create() {
    const result = super.create(...arguments);
    if (result.user) {
      result.user = User.create(result.user);
    }
    return result;
  }

  static async findInvitedBy(user, filter, search, offset) {
    if (!user) {
      return;
    }

    const data = {};
    if (!isNone(filter)) {
      data.filter = filter;
    }
    if (!isNone(search)) {
      data.search = search;
    }
    data.offset = offset || 0;

    const result = await ajax(userPath(`${user.username_lower}/invited.json`), {
      data,
    });

    result.invites = new TrackedArray(
      result.invites.map((i) => Invite.create(i))
    );

    return EmberObject.create(result);
  }

  static reinviteAll() {
    return ajax("/invites/reinvite-all", { type: "POST" });
  }

  static destroyAllExpired(user) {
    return ajax("/invites/destroy-all-expired", {
      type: "POST",
      data: { username: user.username },
    });
  }

  @computed("topics.firstObject.id")
  get topicId() {
    return this.topics?.firstObject?.id;
  }

  set topicId(value) {
    set(this, "topics.firstObject.id", value);
  }

  @computed("topics.firstObject.title")
  get topicTitle() {
    return this.topics?.firstObject?.title;
  }

  set topicTitle(value) {
    set(this, "topics.firstObject.title", value);
  }

  save(data) {
    const promise = this.id
      ? ajax(`/invites/${this.id}`, { type: "PUT", data })
      : ajax("/invites", { type: "POST", data });

    return promise.then((result) => this.setProperties(result));
  }

  destroy() {
    return ajax("/invites", {
      type: "DELETE",
      data: { id: this.id },
    }).then(() => this.set("destroyed", true));
  }

  reinvite() {
    return ajax("/invites/reinvite", {
      type: "POST",
      data: { email: this.email },
    })
      .then(() => this.set("reinvited", true))
      .catch(popupAjaxError);
  }

  @computed("invite_key")
  get shortKey() {
    return this.invite_key.slice(0, 4) + "...";
  }

  @computed("groups")
  get groupIds() {
    return this.groups ? this.groups.map((group) => group.id) : [];
  }

  @computed("topics.firstObject")
  get topic() {
    return this.topics?.firstObject
      ? Topic.create(this.topics?.firstObject)
      : null;
  }

  @computed("email", "domain")
  get emailOrDomain() {
    return this.email || this.domain;
  }
}
