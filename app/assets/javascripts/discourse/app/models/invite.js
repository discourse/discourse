import EmberObject from "@ember/object";
import { alias } from "@ember/object/computed";
import { isNone } from "@ember/utils";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
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

  static findInvitedBy(user, filter, search, offset) {
    if (!user) {
      Promise.resolve();
    }

    const data = {};
    if (!isNone(filter)) {
      data.filter = filter;
    }
    if (!isNone(search)) {
      data.search = search;
    }
    data.offset = offset || 0;

    return ajax(userPath(`${user.username_lower}/invited.json`), {
      data,
    }).then((result) => {
      result.invites = result.invites.map((i) => Invite.create(i));
      return EmberObject.create(result);
    });
  }

  static reinviteAll() {
    return ajax("/invites/reinvite-all", { type: "POST" });
  }

  static destroyAllExpired() {
    return ajax("/invites/destroy-all-expired", { type: "POST" });
  }

  @alias("topics.firstObject.id") topicId;
  @alias("topics.firstObject.title") topicTitle;

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

  @discourseComputed("invite_key")
  shortKey(key) {
    return key.slice(0, 4) + "...";
  }

  @discourseComputed("groups")
  groupIds(groups) {
    return groups ? groups.map((group) => group.id) : [];
  }

  @discourseComputed("topics.firstObject")
  topic(topicData) {
    return topicData ? Topic.create(topicData) : null;
  }

  @discourseComputed("email", "domain")
  emailOrDomain(email, domain) {
    return email || domain;
  }
}
