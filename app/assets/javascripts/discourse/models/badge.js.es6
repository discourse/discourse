import { ajax } from "discourse/lib/ajax";
import BadgeGrouping from "discourse/models/badge-grouping";
import RestModel from "discourse/models/rest";

const Badge = RestModel.extend({
  newBadge: Ember.computed.none("id"),

  url: function() {
    return Discourse.getURL(`/badges/${this.get("id")}/${this.get("slug")}`);
  }.property(),

  /**
    Update this badge with the response returned by the server on save.

    @method updateFromJson
    @param {Object} json The JSON response returned by the server
  **/
  updateFromJson: function(json) {
    const self = this;
    if (json.badge) {
      Object.keys(json.badge).forEach(function(key) {
        self.set(key, json.badge[key]);
      });
    }
    if (json.badge_types) {
      json.badge_types.forEach(function(badgeType) {
        if (badgeType.id === self.get("badge_type_id")) {
          self.set("badge_type", Object.create(badgeType));
        }
      });
    }
  },

  badgeTypeClassName: function() {
    const type = this.get("badge_type.name") || "";
    return "badge-type-" + type.toLowerCase();
  }.property("badge_type.name"),

  /**
    Save and update the badge from the server's response.

    @method save
    @returns {Promise} A promise that resolves to the updated `Badge`
  **/
  save: function(data) {
    let url = "/admin/badges",
      requestType = "POST";
    const self = this;

    if (this.get("id")) {
      // We are updating an existing badge.
      url += "/" + this.get("id");
      requestType = "PUT";
    }

    return ajax(url, {
      type: requestType,
      data: data
    })
      .then(function(json) {
        self.updateFromJson(json);
        return self;
      })
      .catch(function(error) {
        throw new Error(error);
      });
  },

  /**
    Destroy the badge.

    @method destroy
    @returns {Promise} A promise that resolves to the server response
  **/
  destroy: function() {
    if (this.get("newBadge")) return Ember.RSVP.resolve();
    return ajax("/admin/badges/" + this.get("id"), {
      type: "DELETE"
    });
  }
});

Badge.reopenClass({
  /**
    Create `Badge` instances from the server JSON response.

    @method createFromJson
    @param {Object} json The JSON returned by the server
    @returns Array or instance of `Badge` depending on the input JSON
  **/
  createFromJson: function(json) {
    // Create BadgeType objects.
    const badgeTypes = {};
    if ("badge_types" in json) {
      json.badge_types.forEach(function(badgeTypeJson) {
        badgeTypes[badgeTypeJson.id] = Ember.Object.create(badgeTypeJson);
      });
    }

    const badgeGroupings = {};
    if ("badge_groupings" in json) {
      json.badge_groupings.forEach(function(badgeGroupingJson) {
        badgeGroupings[badgeGroupingJson.id] = BadgeGrouping.create(
          badgeGroupingJson
        );
      });
    }

    // Create Badge objects.
    let badges = [];
    if ("badge" in json) {
      badges = [json.badge];
    } else if (json.badges) {
      badges = json.badges;
    }
    badges = badges.map(function(badgeJson) {
      const badge = Badge.create(badgeJson);
      badge.set("badge_type", badgeTypes[badge.get("badge_type_id")]);
      badge.set(
        "badge_grouping",
        badgeGroupings[badge.get("badge_grouping_id")]
      );
      return badge;
    });

    if ("badge" in json) {
      return badges[0];
    } else {
      return badges;
    }
  },

  /**
    Find all `Badge` instances that have been defined.

    @method findAll
    @returns {Promise} a promise that resolves to an array of `Badge`
  **/
  findAll: function(opts) {
    let listable = "";
    if (opts && opts.onlyListable) {
      listable = "?only_listable=true";
    }
    return ajax("/badges.json" + listable, { data: opts }).then(function(
      badgesJson
    ) {
      return Badge.createFromJson(badgesJson);
    });
  },

  /**
    Returns a `Badge` that has the given ID.

    @method findById
    @param {Number} id ID of the badge
    @returns {Promise} a promise that resolves to a `Badge`
  **/
  findById: function(id) {
    return ajax("/badges/" + id).then(function(badgeJson) {
      return Badge.createFromJson(badgeJson);
    });
  }
});

export default Badge;
