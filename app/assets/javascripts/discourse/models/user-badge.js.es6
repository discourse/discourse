import { ajax } from "discourse/lib/ajax";
import Badge from "discourse/models/badge";
import computed from "ember-addons/ember-computed-decorators";

const UserBadge = Discourse.Model.extend({
  @computed
  postUrl: function() {
    if (this.get("topic_title")) {
      return "/t/-/" + this.get("topic_id") + "/" + this.get("post_number");
    }
  }, // avoid the extra bindings for now

  revoke() {
    return ajax("/user_badges/" + this.get("id"), {
      type: "DELETE"
    });
  }
});

UserBadge.reopenClass({
  createFromJson: function(json) {
    // Create User objects.
    if (json.users === undefined) {
      json.users = [];
    }
    var users = {};
    json.users.forEach(function(userJson) {
      users[userJson.id] = Discourse.User.create(userJson);
    });

    // Create Topic objects.
    if (json.topics === undefined) {
      json.topics = [];
    }
    var topics = {};
    json.topics.forEach(function(topicJson) {
      topics[topicJson.id] = Discourse.Topic.create(topicJson);
    });

    // Create the badges.
    if (json.badges === undefined) {
      json.badges = [];
    }
    var badges = {};
    Badge.createFromJson(json).forEach(function(badge) {
      badges[badge.get("id")] = badge;
    });

    // Create UserBadge object(s).
    var userBadges = [];
    if ("user_badge" in json) {
      userBadges = [json.user_badge];
    } else {
      userBadges =
        (json.user_badge_info && json.user_badge_info.user_badges) ||
        json.user_badges;
    }

    userBadges = userBadges.map(function(userBadgeJson) {
      var userBadge = UserBadge.create(userBadgeJson);

      var grantedAtDate = Date.parse(userBadge.get("granted_at"));
      userBadge.set("grantedAt", grantedAtDate);

      userBadge.set("badge", badges[userBadge.get("badge_id")]);
      if (userBadge.get("user_id")) {
        userBadge.set("user", users[userBadge.get("user_id")]);
      }
      if (userBadge.get("granted_by_id")) {
        userBadge.set("granted_by", users[userBadge.get("granted_by_id")]);
      }
      if (userBadge.get("topic_id")) {
        userBadge.set("topic", topics[userBadge.get("topic_id")]);
      }
      return userBadge;
    });

    if ("user_badge" in json) {
      return userBadges[0];
    } else {
      if (json.user_badge_info) {
        userBadges.grant_count = json.user_badge_info.grant_count;
        userBadges.username = json.user_badge_info.username;
      }
      return userBadges;
    }
  },

  /**
    Find all badges for a given username.

    @method findByUsername
    @param {String} username
    @param {Object} options
    @returns {Promise} a promise that resolves to an array of `UserBadge`.
  **/
  findByUsername: function(username, options) {
    if (!username) {
      return Ember.RSVP.resolve([]);
    }
    var url = "/user-badges/" + username + ".json";
    if (options && options.grouped) {
      url += "?grouped=true";
    }
    return ajax(url).then(function(json) {
      return UserBadge.createFromJson(json);
    });
  },

  /**
    Find all badge grants for a given badge ID.

    @method findById
    @param {String} badgeId
    @returns {Promise} a promise that resolves to an array of `UserBadge`.
  **/
  findByBadgeId: function(badgeId, options) {
    if (!options) {
      options = {};
    }
    options.badge_id = badgeId;

    return ajax("/user_badges.json", {
      data: options
    }).then(function(json) {
      return UserBadge.createFromJson(json);
    });
  },

  /**
    Grant the badge having id `badgeId` to the user identified by `username`.

    @method grant
    @param {Integer} badgeId id of the badge to be granted.
    @param {String} username username of the user to be granted the badge.
    @returns {Promise} a promise that resolves to an instance of `UserBadge`.
  **/
  grant: function(badgeId, username, reason) {
    return ajax("/user_badges", {
      type: "POST",
      data: {
        username: username,
        badge_id: badgeId,
        reason: reason
      }
    }).then(function(json) {
      return UserBadge.createFromJson(json);
    });
  }
});

export default UserBadge;
