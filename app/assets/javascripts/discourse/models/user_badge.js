/**
  A data model representing a user badge grant on Discourse

  @class UserBadge
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserBadge = Discourse.Model.extend({
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
    var users = {};
    json.users.forEach(function(userJson) {
      users[userJson.id] = Discourse.User.create(userJson);
    });

    // Create the badges.
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
  }
});
