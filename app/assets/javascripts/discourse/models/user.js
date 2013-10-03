/**
  A data model representing a user on Discourse

  @class User
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.User = Discourse.Model.extend({

  /**
    The user's stream

    @property stream
    @type {Discourse.UserStream}
  **/
  stream: function() {
    return Discourse.UserStream.create({ user: this });
  }.property(),

  /**
    Is this user a member of staff?

    @property staff
    @type {Boolean}
  **/
  staff: Em.computed.or('admin', 'moderator'),


  searchContext: function() {
    return {
      type: 'user',
      id: this.get('username_lower'),
      user: this
    };
  }.property('username_lower'),

  /**
    This user's website.

    @property websiteName
    @type {String}
  **/
  websiteName: function() {
    var website = this.get('website');
    if (Em.isEmpty(website)) { return; }

    return this.get('website').split("/")[2];
  }.property('website'),

  statusIcon: function() {
    var desc;
    if(this.get('admin')) {
      desc = I18n.t('user.admin', {user: this.get("name")});
      return '<i class="icon icon-trophy" title="' + desc +  '" alt="' + desc + '"></i>';
    }
    if(this.get('moderator')){
      desc = I18n.t('user.moderator', {user: this.get("name")});
      return '<i class="icon icon-magic" title="' + desc +  '" alt="' + desc + '"></i>';
    }
    return null;
  }.property('admin','moderator'),

  /**
    Path to this user.

    @property path
    @type {String}
  **/
  path: Discourse.computed.url('username_lower', "/users/%@"),

  /**
    Path to this user's administration

    @property adminPath
    @type {String}
  **/
  adminPath: Discourse.computed.url('username_lower', "/admin/users/%@"),

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
    return Discourse.Site.currentProp('trustLevels').findProperty('id', parseInt(this.get('trust_level'), 10));
  }.property('trust_level'),

  /**
    Changes this user's username.

    @method changeUsername
    @param {String} newUsername The user's new username
    @returns Result of ajax call
  **/
  changeUsername: function(newUsername) {
    return Discourse.ajax("/users/" + this.get('username_lower') + "/preferences/username", {
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
    return Discourse.ajax("/users/" + this.get('username_lower') + "/preferences/email", {
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
    return Discourse.ajax("/users/" + this.get('username_lower'), {
      data: this.getProperties('auto_track_topics_after_msecs',
                               'bio_raw',
                               'website',
                               'name',
                               'email_digests',
                               'email_direct',
                               'email_always',
                               'email_private_messages',
                               'dynamic_favicon',
                               'digest_after_days',
                               'new_topic_duration_minutes',
                               'external_links_in_new_tab',
                               'enable_quoting'),
      type: 'PUT'
    }).then(function(data) {
      user.set('bio_excerpt',data.user.bio_excerpt);

      _.each([
        'enable_quoting', 'external_links_in_new_tab', 'dynamic_favicon'
      ], function(preference) {
        Discourse.User.current().set(preference, user.get(preference));
      });
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
      data: { login: this.get('username') },
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
    var count = 0;
    _.each(this.get('statsExcludingPms'), function(val) {
      count += val.count;
    });
    return count;
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

      if (!Em.isEmpty(json.user.stats)) {
        json.user.stats = Discourse.User.groupStats(_.map(json.user.stats,function(s) {
          if (s.count) s.count = parseInt(s.count, 10);
          return Discourse.UserActionStat.create(s);
        }));
      }

      if (json.user.invited_by) {
        json.user.invited_by = Discourse.User.create(json.user.invited_by);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  /*
    Change avatar selection

    @method toggleAvatarSelection
    @param {Boolean} useUploadedAvatar true if the user is using the uploaded avatar
    @returns {Promise} the result of the toggle avatar selection
  */
  toggleAvatarSelection: function(useUploadedAvatar) {
    return Discourse.ajax("/users/" + this.get("username_lower") + "/preferences/avatar/toggle", {
      type: 'PUT',
      data: { use_uploaded_avatar: useUploadedAvatar }
    });
  },

  /**
    Determines whether the current user is allowed to upload a file.

    @method isAllowedToUploadAFile
    @param {string} type The type of the upload (image, attachment)
    @returns true if the current user is allowed to upload a file
  **/
  isAllowedToUploadAFile: function(type) {
    return this.get('staff') ||
           this.get('trust_level') > 0 ||
           Discourse.SiteSettings['newuser_max_' + type + 's'] > 0;
  }

});

Discourse.User.reopenClass(Discourse.Singleton, {


  /**
    Find a `Discourse.User` for a given username.

    @method findByUsername
    @returns {Promise} a promise that resolves to a `Discourse.User`
  **/
  findByUsername: function(username) {
    var user = Discourse.User.create({username: username});
    return user.findDetails();
  },

  /**
    The current singleton will retrieve its attributes from the `PreloadStore`
    if it exists. Otherwise, no instance is created.

    @method createCurrent
    @returns {Discourse.User} the user, if logged in.
  **/
  createCurrent: function() {
    var userJson = PreloadStore.get('currentUser');
    if (userJson) { return Discourse.User.create(userJson); }
    return null;
  },

  /**
    Logs out the currently logged in user

    @method logout
    @returns {Promise} resolved when the logout finishes
  **/
  logout: function() {
    var discourseUserClass = this;
    return Discourse.ajax("/session/" + Discourse.User.currentProp('username'), {
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
  checkUsername: function(username, email, forUserId) {
    return Discourse.ajax('/users/check_username', {
      data: { username: username, email: email, for_user_id: forUserId }
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
      action_type: Discourse.UserAction.TYPES.replies
    });

    stats.filterProperty('isResponse').forEach(function (stat) {
      responses.set('count', responses.get('count') + stat.get('count'));
    });

    var result = Em.A();
    result.pushObjects(stats.rejectProperty('isResponse'));

    var insertAt = 0;
    result.forEach(function(item, index){
     if(item.action_type === Discourse.UserAction.TYPES.topics || item.action_type === Discourse.UserAction.TYPES.posts){
       insertAt = index + 1;
     }
    });
    if(responses.count > 0) {
      result.insertAt(insertAt, responses);
    }
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
