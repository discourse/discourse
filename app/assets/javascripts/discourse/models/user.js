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
  websiteName: function() {
    return this.get('website').split("/")[2];
  }.property('website'),

  hasWebsite: function() {
    return this.present('website');
  }.property('website'),

  statusIcon: function() {
    var desc;
    if(this.get('admin')) {
      desc = Em.String.i18n('user.admin', {user: this.get("name")}); 
      return '<i class="icon icon-trophy" title="' + desc +  '" alt="' + desc + '"></i>';
    }
    if(this.get('moderator')){
      desc = Em.String.i18n('user.moderator', {user: this.get("name")}); 
      return '<i class="icon icon-magic" title="' + desc +  '" alt="' + desc + '"></i>';
    }
    return null;
  }.property('admin','moderator'),

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
    return Discourse.ajax({
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
    return Discourse.ajax({
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
    @returns {Promise} the result of the operation
  **/
  save: function() {
    var user = this;
    return Discourse.ajax(Discourse.getURL("/users/") + this.get('username').toLowerCase(), {
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
      success: function(data) {
        user.set('bio_excerpt',data.user.bio_excerpt);
      }
    }).then(function() {
      Discourse.set('currentUser.enable_quoting', user.get('enable_quoting'));
      Discourse.set('currentUser.external_links_in_new_tab', user.get('external_links_in_new_tab'));
    });
  },

  /**
    Changes the password and calls the callback function on AJAX.complete.

    @method changePassword
    @returns {Promise} the result of the change password operation
  **/
  changePassword: function() {
    return Discourse.ajax(Discourse.getURL("/session/forgot_password"), {
      dataType: 'json',
      data: {
        login: this.get('username')
      },
      type: 'POST'
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
    var user = this;
    var stream = this.get('stream');
    return Discourse.ajax({
      url: Discourse.getURL("/user_actions/") + id + ".json",
      dataType: 'json',
      cache: 'false'
    }).then(function(result) {
      if (result) {

        if ((user.get('streamFilter') || result.action_type) !== result.action_type) return;

        var action = Em.A();
        action.pushObject(Discourse.UserAction.create(result));
        action = Discourse.UserAction.collapseStream(action);

        user.set('totalItems', user.get('totalItems') + 1);

        return stream.insertAt(0, action[0]);
      }
    });
  },

  /**
    Loads more user actions, and then calls a callback if defined.

    @method loadMoreUserActions
    @returns {Promise} the content of the user actions
  **/
  loadMoreUserActions: function() {
    var user = this;
    var stream = user.get('stream');
    if (!stream) return;

    var url = Discourse.getURL("/user_actions?offset=") + this.get('totalItems') + "&user_id=" + (this.get("id"));
    if (this.get('streamFilter')) {
      url += "&filter=" + (this.get('streamFilter'));
    }

    return Discourse.ajax(url, { cache: 'false' }).then( function(result) {
      if (result && result.user_actions && result.user_actions.each) {
        var copy = Em.A();
        result.user_actions.each(function(i) {
          return copy.pushObject(Discourse.UserAction.create(i));
        });
        copy = Discourse.UserAction.collapseStream(copy);
        stream.pushObjects(copy);
        user.set('stream', stream);
        user.set('totalItems', user.get('totalItems') + result.user_actions.length);
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
  sentItemsCount: function() {
    var r;
    r = 0;
    this.get('stats').each(function(s) {
      if (s.action_type === Discourse.UserAction.NEW_PRIVATE_MESSAGE) {
        r = s.count;
        return false;
      }
    });
    return r;
  }.property('stats.@each'),

  onDetailsLoaded: function(callback){
    var _this = this;
    this.set("loading",false);

    if(callback){
      this.onDetailsLoadedCallbacks = this.onDetailsLoadedCallbacks || [];
      this.onDetailsLoadedCallbacks.push(callback);
    } else {
      var callbacks = this.onDetailsLoadedCallbacks;
      $.each(callbacks, function(){
        this.apply(_this);
      });
    }
  },

  /**
    Load extra details for the user

    @method loadDetails
  **/
  loadDetails: function() {

    this.set("loading",true);
    // Check the preload store first
    var user = this;
    var username = this.get('username');
    PreloadStore.getAndRemove("user_" + username, function() {
      return Discourse.ajax({ url: Discourse.getURL("/users/") + username + '.json' });
    }).then(function (json) {
      // Create a user from the resulting JSON
      json.user.stats = Discourse.User.groupStats(json.user.stats.map(function(s) {
        var stat = Em.Object.create(s);
        stat.set('isPM', stat.get('action_type') === Discourse.UserAction.NEW_PRIVATE_MESSAGE ||
                         stat.get('action_type') === Discourse.UserAction.GOT_PRIVATE_MESSAGE);
        stat.set('description', Em.String.i18n('user_action_groups.' + stat.get('action_type')));
        return stat;
      }));

      var count = 0;
      if (json.user.stream) {
        count = json.user.stream.length;
        json.user.stream = Discourse.UserAction.collapseStream(json.user.stream.map(function(ua) {
          return Discourse.UserAction.create(ua);
        }));
      }

      user.setProperties(json.user);
      user.set('totalItems', count);
      user.onDetailsLoaded();
    });
  }

});

Discourse.User.reopenClass({
  /**
    Checks if given username is valid for this email address

    @method checkUsername
    @param {String} username A username to check
    @param {String} email An email address to check
  **/
  checkUsername: function(username, email) {
    return Discourse.ajax({
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
              description: Em.String.i18n("user_action_groups." + k),
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
    return Discourse.ajax({
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
