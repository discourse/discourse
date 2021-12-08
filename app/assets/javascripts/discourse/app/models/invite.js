import EmberObject from "@ember/object";
import { alias } from "@ember/object/computed";
import { Promise } from "rsvp";
import discourseComputed from "discourse-common/utils/decorators";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import { isNone } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";

const Invite = EmberObject.extend({
  save(data) {
    const promise = this.id
      ? ajax(`/invites/${this.id}`, { type: "PUT", data })
      : ajax("/invites", { type: "POST", data });

    return promise.then((result) => this.setProperties(result));
  },

  destroy() {
    return ajax("/invites", {
      type: "DELETE",
      data: { id: this.id },
    }).then(() => this.set("destroyed", true));
  },

  reinvite() {
    return ajax("/invites/reinvite", {
      type: "POST",
      data: { email: this.email },
    })
      .then(() => this.set("reinvited", true))
      .catch(popupAjaxError);
  },

  @discourseComputed("invite_key")
  shortKey(key) {
    return key.substr(0, 4) + "...";
  },

  @discourseComputed("groups")
  groupIds(groups) {
    return groups ? groups.map((group) => group.id) : [];
  },

  @discourseComputed("topics.firstObject")
  topic(topicData) {
    return topicData ? Topic.create(topicData) : null;
  },

  @discourseComputed("email", "domain")
  emailOrDomain(email, domain) {
    return email || domain;
  },

  topicId: alias("topics.firstObject.id"),
  topicTitle: alias("topics.firstObject.title"),
});

Invite.reopenClass({
  create() {
    const result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = User.create(result.user);
    }
    return result;
  },

  findInvitedBy(user, filter, search, offset) {
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
  },

  reinviteAll() {
    return ajax("/invites/reinvite-all", { type: "POST" });
  },

  destroyAllExpired() {
    return ajax("/invites/destroy-all-expired", { type: "POST" });
  },
});

export default Invite;
