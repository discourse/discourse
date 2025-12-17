import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { isNone } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
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

  @trackedArray topics;

  @dependentKeyCompat
  get topicId() {
    return this.topics?.[0]?.id;
  }

  @dependentKeyCompat
  get topicTitle() {
    return this.topics?.[0]?.title;
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
