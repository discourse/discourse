import { none } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import BadgeGrouping from "discourse/models/badge-grouping";
import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";

const Badge = RestModel.extend({
  newBadge: none("id"),

  @computed
  url() {
    return Discourse.getURL(`/badges/${this.id}/${this.slug}`);
  },

  updateFromJson(json) {
    if (json.badge) {
      Object.keys(json.badge).forEach(key => this.set(key, json.badge[key]));
    }
    if (json.badge_types) {
      json.badge_types.forEach(badgeType => {
        if (badgeType.id === this.badge_type_id) {
          this.set("badge_type", Object.create(badgeType));
        }
      });
    }
  },

  @computed("badge_type.name")
  badgeTypeClassName(type) {
    type = type || "";
    return `badge-type-${type.toLowerCase()}`;
  },

  save(data) {
    let url = "/admin/badges",
      type = "POST";

    if (this.id) {
      // We are updating an existing badge.
      url += `/${this.id}`;
      type = "PUT";
    }

    return ajax(url, { type, data })
      .then(json => {
        this.updateFromJson(json);
        return this;
      })
      .catch(error => {
        throw new Error(error);
      });
  },

  destroy() {
    if (this.newBadge) return Ember.RSVP.resolve();

    return ajax(`/admin/badges/${this.id}`, {
      type: "DELETE"
    });
  }
});

Badge.reopenClass({
  createFromJson(json) {
    // Create BadgeType objects.
    const badgeTypes = {};
    if ("badge_types" in json) {
      json.badge_types.forEach(
        badgeTypeJson =>
          (badgeTypes[badgeTypeJson.id] = EmberObject.create(badgeTypeJson))
      );
    }

    const badgeGroupings = {};
    if ("badge_groupings" in json) {
      json.badge_groupings.forEach(
        badgeGroupingJson =>
          (badgeGroupings[badgeGroupingJson.id] = BadgeGrouping.create(
            badgeGroupingJson
          ))
      );
    }

    // Create Badge objects.
    let badges = [];
    if ("badge" in json) {
      badges = [json.badge];
    } else if (json.badges) {
      badges = json.badges;
    }
    badges = badges.map(badgeJson => {
      const badge = Badge.create(badgeJson);
      badge.setProperties({
        badge_type: badgeTypes[badge.badge_type_id],
        badge_grouping: badgeGroupings[badge.badge_grouping_id]
      });
      return badge;
    });

    if ("badge" in json) {
      return badges[0];
    } else {
      return badges;
    }
  },

  findAll(opts) {
    let listable = "";
    if (opts && opts.onlyListable) {
      listable = "?only_listable=true";
    }

    return ajax(`/badges.json${listable}`, { data: opts }).then(badgesJson =>
      Badge.createFromJson(badgesJson)
    );
  },

  findById(id) {
    return ajax(`/badges/${id}`).then(badgeJson =>
      Badge.createFromJson(badgeJson)
    );
  }
});

export default Badge;
