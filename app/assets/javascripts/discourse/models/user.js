/**
  A data model representing a user on Discourse

  @class User
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.User = Discourse.Model.extend({

  /**
    Large version of this user's avatar.

    @property avatarLarge
    @type {String}
  **/
  avatarLarge: (function() {
    return Discourse.Utilities.avatarUrl(this.get('username'), 'large', this.get('avatar_template'));
  }).property('username'),

  /**
    Small version of this user's avatar.

    @property avatarSmall
    @type {String}
  **/
  avatarSmall: (function() {
  return Discourse.Utilities.avatarUrl(this.get('username'), 'small', this.get('avatar_template'));
  }).property('username'),

  /**
    This user's website.

    @property websiteName
    @type {String}
  **/
  websiteName: (function() {
    return this.get('website').split("/")[2];
  }).property('website'),

  /**
    Path to this user.

    @property path
    @type {String}
  **/
  path: (function() {
    return Discourse.getURL("/users/") + (this.get('username_lower'));
  }).property('username'),

  /**
    Path to this user's administration

    @property adminPath
    @type {String}
  **/
  adminPath: (function() {
    return Discourse.getURL("/admin/users/") + (this.get('username_lower'));
  }).property('username'),

  /**
    This user's username in lowercase.

    @property username_lower
    @type {String}
  **/
  username_lower: (function() {
    return this.get('username').toLowerCase();
  }).property('username'),

  /**
    This user's trust level.

    @property trustLevel
    @type {Integer}
  **/
  trustLevel: (function() {
    return Discourse.get('site.trust_levels').findProperty('id', this.get('trust_level'));
  }).property('trust_level'),

  /**
    Changes this user's username.

    @method changeUsername
    @param {String} newUsername The user's new username
    @returns Result of ajax call
  **/
  changeUsername: function(newUsername) {
    return $.ajax({
      url: Discourse.getURL("/users/") + (this.get('username_lower')) + "/preferences/username",
      type: 'PUT',
      data: {
        new_username: newUsername
      }
    });
  },

  /**
    Changes this user's email address.

    @method changeEmail
    @param {String} email The user's new email address\
    @returns Result of ajax call
  **/
  changeEmail: function(email) {
    return $.ajax({
      url: Discourse.getURL("/users/") + (this.get('username_lower')) + "/preferences/email",
      type: 'PUT',
      data: {
        email: email
      }
    });
  },

  /**
    Returns a copy of this user.

    @method copy
    @returns {User}
  **/
  copy: function() {
    return Discourse.User.create(this.getProperties(Ember.keys(this)));
  },

  /**
    Save's this user's properties over AJAX via a PUT request.

    @method save
    @param {Function} finished Function called on completion of AJAX call
    @returns The result of finished(true) on a success, the result of finished(false) on an error
  **/
  save: function(finished) {
    var _this = this;
    $.ajax(Discourse.getURL("/users/") + this.get('username').toLowerCase(), {
      data: this.getProperties('auto_track_topics_after_msecs',
                               'bio_raw',
                               'website',
                               'name',
                               'email_digests',
                               'email_direct',
                               'email_private_messages',
                               'digest_after_days',
                               'new_topic_duration_minutes',
                               'external_links_in_new_tab',
                               'enable_quoting'),
      type: 'PUT',
      success: function() {
        Discourse.set('currentUser.enable_quoting', _this.get('enable_quoting'));
        Discourse.set('currentUser.external_links_in_new_tab', _this.get('external_links_in_new_tab'));
        return finished(true);
      },
      error: function() { return finished(false); }
    });
  },

  /**
    Changes the password and calls the callback function on AJAX.complete.

    @method changePassword
    @param {Function} callback Function called on completion of AJAX call
    @returns The result of the callback() function on complete
  **/
  changePassword: function(callback) {
    var good;
    good = false;
  $.ajax({
      url: Discourse.getURL("/session/forgot_password"),
      dataType: 'json',
      data: {
        username: this.get('username')
      },
      type: 'POST',
      success: function() { good = true; },
      complete: function() {
        var message;
        message = "error";
        if (good) {
          message = "email sent";
        }
        return callback(message);
      }
    });
  },

  /**
    Filters out this user's stream of user actions by a given filter

    @method filterStream
    @param {String} filter
  **/
  filterStream: function(filter) {
    if (Discourse.UserAction.statGroups[filter]) {
      filter = Discourse.UserAction.statGroups[filter].join(",");
    }
    this.set('streamFilter', filter);
    this.set('stream', Em.A());
    this.set('totalItems', 0);
    return this.loadMoreUserActions();
  },

  /**
    Loads a single user action by id.

    @method loadUserAction
    @param {Integer} id The id of the user action being loaded
    @returns A stream of the user's actions containing the action of id
  **/
  loadUserAction: function(id) {
    var stream,
      _this = this;
    stream = this.get('stream');
    $.ajax({
      url: Discourse.getURL("/user_actions/") + id + ".json",
      dataType: 'json',
      cache: 'false',
      success: function(result) {
        if (result) {
          var action;

          if ((_this.get('streamFilter') || result.action_type) !== result.action_type) {
            return;
          }

          action = Em.A();
          action.pushObject(Discourse.UserAction.create(result));
          action = Discourse.UserAction.collapseStream(action);

          _this.set('totalItems', _this.get('totalItems') + 1);

          return stream.insertAt(0, action[0]);
        }
      }
    });
  },

  /**
    Loads more user actions, and then calls a callback if defined.

    @method loadMoreUserActions
    @param {String} callback Called after completion, on success of AJAX call, if it is defined
    @returns the result of the callback
  **/
  loadMoreUserActions: function(callback) {
    var stream, url,
      _this = this;
    stream = this.get('stream');
    if (!stream) return;

    url = Discourse.getURL("/user_actions?offset=") + this.get('totalItems') + "&user_id=" + (this.get("id"));
    if (this.get('streamFilter')) {
      url += "&filter=" + (this.get('streamFilter'));
    }

    return $.ajax({
      url: url,
      dataType: 'json',
      cache: 'false',
      success: function(result) {
        var copy;
        if (result && result.user_actions && result.user_actions.each) {
          copy = Em.A();
          result.user_actions.each(function(i) {
            return copy.pushObject(Discourse.UserAction.create(i));
          });
          copy = Discourse.UserAction.collapseStream(copy);
          stream.pushObjects(copy);
          _this.set('stream', stream);
          _this.set('totalItems', _this.get('totalItems') + result.user_actions.length);
        }
        if (callback) {
          return callback();
        }
      }
    });
  },

  /**
  The user's stat count, excluding PMs.

    @property statsCountNonPM
    @type {Integer}
  **/
  statsCountNonPM: (function() {
    var stats, total;
    total = 0;
    if (!(stats = this.get('stats'))) return 0;
    this.get('stats').each(function(s) {
      if (!s.get("isPM")) {
        total += parseInt(s.count, 10);
      }
    });
    return total;
  }).property('stats.@each'),

  /**
  The user's stats, excluding PMs.

    @property statsExcludingPms
    @type {Array}
  **/
  statsExcludingPms: (function() {
    var r;
    r = [];
    if (this.blank('stats')) return r;
    this.get('stats').each(function(s) {
      if (!s.get('isPM')) {
        return r.push(s);
      }
    });
    return r;
  }).property('stats.@each'),

  /**
  This user's stats, only including PMs.

    @property statsPmsOnly
    @type {Array}
  **/
  statsPmsOnly: (function() {
    var r;
    r = [];
    if (this.blank('stats')) return r;
    this.get('stats').each(function(s) {
      if (s.get('isPM')) return r.push(s);
    });
    return r;
  }).property('stats.@each'),

  /**
  Number of items in this user's inbox.

    @property inboxCount
    @type {Integer}
  **/
  inboxCount: (function() {
    var r;
    r = 0;
    this.get('stats').each(function(s) {
      if (s.action_type === Discourse.UserAction.GOT_PRIVATE_MESSAGE) {
        r = s.count;
        return false;
      }
    });
    return r;
  }).property('stats.@each'),

  /**
  Number of items this user has sent.

    @property sentItemsCount
    @type {Integer}
  **/
  sentItemsCount: (function() {
    var r;
    r = 0;
    this.get('stats').each(function(s) {
      if (s.action_type === Discourse.UserAction.NEW_PRIVATE_MESSAGE) {
        r = s.count;
        return false;
      }
    });
    return r;
  }).property('stats.@each')
});

Discourse.User.reopenClass({
  /**
    Checks if given username is valid for this email address

    @method checkUsername
    @param {String} username A username to check
    @param {String} email An email address to check
  **/
  checkUsername: function(username, email) {
    return $.ajax({
      url: Discourse.getURL('/users/check_username'),
      type: 'GET',
      data: {
        username: username,
        email: email
      }
    });
  },

  /**
    Groups the user's statistics

    @method groupStats
    @param {Array} Given stats
    @returns {Object}
  **/
  groupStats: function(stats) {
    var g,
      _this = this;
    g = {};
    stats.each(function(s) {
      var c, found, k, v, _ref;
      found = false;
      _ref = Discourse.UserAction.statGroups;
      for (k in _ref) {
        v = _ref[k];
        if (v.contains(s.action_type)) {
          found = true;
          if (!g[k]) {
            g[k] = Em.Object.create({
              description: Em.String.i18n("user_action_descriptions." + k),
              count: 0,
              action_type: parseInt(k, 10)
            });
          }
          g[k].count += parseInt(s.count, 10);
          c = g[k].count;
          if (s.action_type === k) {
            g[k] = s;
            s.count = c;
          }
        }
      }
      if (!found) {
        g[s.action_type] = s;
      }
    });
    return stats.map(function(s) {
      return g[s.action_type];
    }).exclude(function(s) {
      return !s;
    });
  },

  /**
    Finds a user based on a username

    @method find
    @param {String} username The username
    @returns a promise that will resolve to the user
  **/
  find: function(username) {

    // Check the preload store first
    return PreloadStore.getAndRemove("user_" + username, function() {
      return $.ajax({ url: Discourse.getURL("/users/") + username + '.json' });
    }).then(function (json) {

      // Create a user from the resulting JSON
      json.user.stats = Discourse.User.groupStats(json.user.stats.map(function(s) {
        var stat = Em.Object.create(s);
        stat.set('isPM', stat.get('action_type') === Discourse.UserAction.NEW_PRIVATE_MESSAGE ||
                         stat.get('action_type') === Discourse.UserAction.GOT_PRIVATE_MESSAGE);
        return stat;
      }));

      var count = 0;
      if (json.user.stream) {
        count = json.user.stream.length;
        json.user.stream = Discourse.UserAction.collapseStream(json.user.stream.map(function(ua) {
          return Discourse.UserAction.create(ua);
        }));
      }

      var user = Discourse.User.create(json.user);
      user.set('totalItems', count);
      return user;
    });
  },

  /**
  Creates a new account over POST

    @method createAccount
    @param {String} name This user's name
    @param {String} email This user's email
    @param {String} password This user's password
    @param {String} passwordConfirm This user's confirmed password
    @param {String} challenge
    @returns Result of ajax call
  **/
  createAccount: function(name, email, password, username, passwordConfirm, challenge) {
    return $.ajax({
      url: Discourse.getURL("/users"),
      dataType: 'json',
      data: {
        name: name,
        email: email,
        password: password,
        username: username,
        password_confirmation: passwordConfirm,
        challenge: challenge
      },
      type: 'POST'
    });
  }
});
