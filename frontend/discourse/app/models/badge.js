import EmberObject from "@ember/object";
import { alias, none } from "@ember/object/computed";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import BadgeGrouping from "discourse/models/badge-grouping";
import RestModel from "discourse/models/rest";

export default class Badge extends RestModel {
  static createFromJson(json) {
    // Create BadgeType objects.
    const badgeTypes = {};
    if ("badge_types" in json) {
      json.badge_types.forEach(
        (badgeTypeJson) =>
          (badgeTypes[badgeTypeJson.id] = EmberObject.create(badgeTypeJson))
      );
    }

    const badgeGroupings = {};
    if ("badge_groupings" in json) {
      json.badge_groupings.forEach(
        (badgeGroupingJson) =>
          (badgeGroupings[badgeGroupingJson.id] =
            BadgeGrouping.create(badgeGroupingJson))
      );
    }

    // Create Badge objects.
    let badges = [];
    if ("badge" in json) {
      badges = [json.badge];
    } else if (json.badges) {
      badges = json.badges;
    }
    badges = badges.map((badgeJson) => {
      const badge = Badge.create(badgeJson);
      badge.setProperties({
        badge_type: badgeTypes[badge.badge_type_id],
        badge_grouping: badgeGroupings[badge.badge_grouping_id],
      });
      return badge;
    });

    if ("badge" in json) {
      return badges[0];
    } else {
      return badges;
    }
  }

  static findAll(opts) {
    let listable = "";
    if (opts && opts.onlyListable) {
      listable = "?only_listable=true";
    }

    return ajax(`/badges.json${listable}`, { data: opts }).then((badgesJson) =>
      Badge.createFromJson(badgesJson)
    );
  }

  static findById(id) {
    return ajax(`/badges/${id}`).then((badgeJson) =>
      Badge.createFromJson(badgeJson)
    );
  }

  @none("id") newBadge;

  @alias("image_url") image;

  @discourseComputed
  url() {
    return getURL(`/badges/${this.id}/${this.slug}`);
  }

  updateFromJson(json) {
    if (json.badge) {
      Object.keys(json.badge).forEach((key) => this.set(key, json.badge[key]));
    }
    if (json.badge_types) {
      json.badge_types.forEach((badgeType) => {
        if (badgeType.id === this.badge_type_id) {
          this.set("badge_type", Object.create(badgeType));
        }
      });
    }
  }

  @discourseComputed("badge_type.name")
  badgeTypeClassName(type) {
    type = type || "";
    return `badge-type-${type.toLowerCase()}`;
  }

  save(data) {
    let url = "/admin/badges",
      type = "POST";

    if (this.id) {
      // We are updating an existing badge.
      url += `/${this.id}`;
      type = "PUT";
    }

    return ajax(url, { type, data }).then((json) => {
      this.updateFromJson(json);
      return this;
    });
  }

  destroy() {
    if (this.newBadge) {
      return Promise.resolve();
    }

    return ajax(`/admin/badges/${this.id}`, {
      type: "DELETE",
    });
  }
}
