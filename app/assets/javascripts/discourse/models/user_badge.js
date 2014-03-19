/**
  A data model representing a user badge grant on Discourse

  @class UserBadge
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserBadge = Discourse.Model.extend({
  /**
    Revoke this badge.

    @method revoke
    @returns {Promise} a promise that resolves when the badge has been revoked.
  **/
  revoke: function() {
    return Discourse.ajax("/user_badges/" + this.get('id'), {
      type: "DELETE"
    });
  }
});

Discourse.UserBadge.reopenClass({
  /**
    Create `Discourse.UserBadge` instances from the server JSON response.

    @method createFromJson
    @param {Object} json The JSON returned by the server
    @returns Array or instance of `Discourse.UserBadge` depending on the input JSON
  **/
  createFromJson: function(json) {
    // Create User objects.
    if (json.users === undefined) { json.users = []; }
    var users = {};
    json.users.forEach(function(userJson) {
      users[userJson.id] = Discourse.User.create(userJson);
    });

    // Create the badges.
    if (json.badges === undefined) { json.badges = []; }
    var badges = {};
    Discourse.Badge.createFromJson(json).forEach(function(badge) {
      badges[badge.get('id')] = badge;
    });

    // Create UserBadge object(s).
    var userBadges = [];
    if ("user_badge" in json) {
      userBadges = [json.user_badge];
    } else {
      userBadges = json.user_badges;
    }

    userBadges = userBadges.map(function(userBadgeJson) {
      var userBadge = Discourse.UserBadge.create(userBadgeJson);
      userBadge.set('badge', badges[userBadge.get('badge_id')]);
      if (userBadge.get('granted_by_id')) {
        userBadge.set('granted_by', users[userBadge.get('granted_by_id')]);
      }
      return userBadge;
    });

    if ("user_badge" in json) {
      return userBadges[0];
    } else {
      return userBadges;
    }
  },

  /**
    Find all badges for a given username.

    @method findByUsername
    @returns {Promise} a promise that resolves to an array of `Discourse.UserBadge`.
  **/
  findByUsername: function(username) {
    return Discourse.ajax("/user_badges.json?username=" + username).then(function(json) {
      return Discourse.UserBadge.createFromJson(json);
    });
  },

  /**
    Grant the badge having id `badgeId` to the user identified by `username`.

    @method grant
    @param {Integer} badgeId id of the badge to be granted.
    @param {String} username username of the user to be granted the badge.
    @returns {Promise} a promise that resolves to an instance of `Discourse.UserBadge`.
  **/
  grant: function(badgeId, username) {
    return Discourse.ajax("/user_badges", {
      type: "POST",
      data: {
        username: username,
        badge_id: badgeId
      }
    }).then(function(json) {
      return Discourse.UserBadge.createFromJson(json);
    });
  }
});
