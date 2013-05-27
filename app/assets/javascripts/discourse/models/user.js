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

  searchContext: function() {
    return ({ type: 'user', id: this.get('username_lower'), user: this });
  }.property('username_lower'),

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
  path: function() {
    return Discourse.getURL("/users/") + (this.get('username_lower'));
  }.property('username'),

  /**
    Path to this user's administration

    @property adminPath
    @type {String}
  **/
  adminPath: function() {
    return Discourse.getURL("/admin/users/") + (this.get('username_lower'));
  }.property('username'),

  /**
    This user's username in lowercase.

    @property username_lower
    @type {String}
  **/
  username_lower: function() {
    return this.get('username').toLowerCase();
  }.property('username'),

  /**
    This user's trust level.

    @property trustLevel
    @type {Integer}
  **/
  trustLevel: function() {
    return Discourse.Site.instance().get('trust_levels').findProperty('id', this.get('trust_level'));
  }.property('trust_level'),

  /**
    Changes this user's username.

    @method changeUsername
    @param {String} newUsername The user's new username
    @returns Result of ajax call
  **/
  changeUsername: function(newUsername) {
    return Discourse.ajax("/users/" + (this.get('username_lower')) + "/preferences/username", {
      type: 'PUT',
      data: { new_username: newUsername }
    });
  },

  /**
    Changes this user's email address.

    @method changeEmail
    @param {String} email The user's new email address\
    @returns Result of ajax call
  **/
  changeEmail: function(email) {
    return Discourse.ajax("/users/" + (this.get('username_lower')) + "/preferences/email", {
      type: 'PUT',
      data: { email: email }
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
    return Discourse.ajax("/users/" + this.get('username').toLowerCase(), {
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
      type: 'PUT'
    }).then(function(data) {
      user.set('bio_excerpt',data.user.bio_excerpt);
      Discourse.User.current().set('enable_quoting', user.get('enable_quoting'));
      Discourse.User.current().set('external_links_in_new_tab', user.get('external_links_in_new_tab'));
    });
  },

  /**
    Changes the password and calls the callback function on AJAX.complete.

    @method changePassword
    @returns {Promise} the result of the change password operation
  **/
  changePassword: function() {
    return Discourse.ajax("/session/forgot_password", {
      dataType: 'json',
      data: {
        login: this.get('username')
      },
      type: 'POST'
    });
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
    return Discourse.ajax("/user_actions/" + id + ".json", { cache: 'false' }).then(function(result) {
      if (result) {
        if ((user.get('streamFilter') || result.action_type) !== result.action_type) return;
        var action = Discourse.UserAction.collapseStream([Discourse.UserAction.create(result)]);
        stream.set('itemsLoaded', user.get('itemsLoaded') + 1);
        stream.insertAt(0, action[0]);
      }
    });
  },

  /**
  The user's stat count, excluding PMs.

    @property statsCountNonPM
    @type {Integer}
  **/
  statsCountNonPM: function() {
    if (this.blank('statsExcludingPms')) return 0;
    return this.get('statsExcludingPms').getEach('count').reduce(function (accum, val) {
      return accum + val;
    });
  }.property('statsExcludingPms.@each.count'),

  /**
  The user's stats, excluding PMs.

    @property statsExcludingPms
    @type {Array}
  **/
  statsExcludingPms: function() {
    if (this.blank('stats')) return [];
    return this.get('stats').rejectProperty('isPM');
  }.property('stats.@each.isPM'),

  /**
  This user's stats, only including PMs.

    @property statsPmsOnly
    @type {Array}
  **/
  statsPmsOnly: function() {
    if (this.blank('stats')) return [];
    return this.get('stats').filterProperty('isPM');
  }.property('stats.@each.isPM'),


  findDetails: function() {
    var user = this;
    return PreloadStore.getAndRemove("user_" + user.get('username'), function() {
      return Discourse.ajax("/users/" + user.get('username') + '.json');
    }).then(function (json) {
      json.user.stats = Discourse.User.groupStats(json.user.stats.map(function(s) {
        if (s.count) s.count = parseInt(s.count, 10);
        return Discourse.UserActionStat.create(s);
      }));

      if (json.user.invited_by) {
        json.user.invited_by = Discourse.User.create(json.user.invited_by);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  findStream: function(filter) {
    if (Discourse.UserAction.statGroups[filter]) {
      filter = Discourse.UserAction.statGroups[filter].join(",");
    }

    var stream = Discourse.UserStream.create({
      itemsLoaded: 0,
      content: [],
      filter: filter,
      user: this
    });

    stream.findItems();
    return stream;
  }

});

Discourse.User.reopenClass({

  /**
    Returns the currently logged in user

    @method current
    @param {String} optional property to return from the user if the user exists
    @returns {Discourse.User} the logged in user
  **/
  current: function(property) {
    if (!this.currentUser) {
      var userJson = PreloadStore.get('currentUser');
      if (userJson) {
        this.currentUser = Discourse.User.create(userJson);
      }
    }

    // If we found the current user
    if (this.currentUser && property) {
      return this.currentUser.get(property);
    }

    return this.currentUser;
  },

  /**
    Logs out the currently logged in user

    @method logout
    @returns {Promise} resolved when the logout finishes
  **/
  logout: function() {
    var discourseUserClass = this;
    return Discourse.ajax("/session/" + Discourse.User.current('username'), {
      type: 'DELETE'
    }).then(function () {
      discourseUserClass.currentUser = null;
    });
  },


  /**
    Checks if given username is valid for this email address

    @method checkUsername
    @param {String} username A username to check
    @param {String} email An email address to check
  **/
  checkUsername: function(username, email) {
    return Discourse.ajax('/users/check_username', {
      data: { username: username, email: email }
    });
  },

  /**
    Groups the user's statistics

    @method groupStats
    @param {Array} Given stats
    @returns {Object}
  **/
  groupStats: function(stats) {
    var responses = Discourse.UserActionStat.create({
      count: 0,
      action_type: Discourse.UserAction.RESPONSE
    });

    stats.filterProperty('isResponse').forEach(function (stat) {
      responses.set('count', responses.get('count') + stat.get('count'));
    });

    var result = Em.A();
    result.pushObject(responses);
    result.pushObjects(stats.rejectProperty('isResponse'));
    return(result);
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
    return Discourse.ajax("/users", {
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
