/**
  A data model representing a user on Discourse

  @class User
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.User = Discourse.Model.extend({

  hasPMs: Em.computed.gt("private_messages_stats.all", 0),
  hasStartedPMs: Em.computed.gt("private_messages_stats.mine", 0),
  hasUnreadPMs: Em.computed.gt("private_messages_stats.unread", 0),

  /**
    The user's stream

    @property stream
    @type {Discourse.UserStream}
  **/
  stream: function() {
    return Discourse.UserStream.create({ user: this });
  }.property(),

  /**
    The user's posts stream

    @property postsStream
    @type {Discourse.UserPostsStream}
  **/
  postsStream: function() {
    return Discourse.UserPostsStream.create({ user: this });
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
    This user's display name. Returns the name if possible, otherwise returns the
    username.

    @property displayName
    @type {String}
  **/
  displayName: function() {
    if (Discourse.SiteSettings.enable_names && !this.blank('name')) {
      return this.get('name');
    }
    return this.get('username');
  }.property('username', 'name'),

  /**
    This user's profile background(in CSS).

    @property websiteName
    @type {String}
  **/
  profileBackground: function() {
    var background = this.get('profile_background');
    if(Em.isEmpty(background) || !Discourse.SiteSettings.allow_profile_backgrounds) { return; }

    return 'background-image: url(' + background + ')';
  }.property('profile_background'),

  statusIcon: function() {
    var name = Handlebars.Utils.escapeExpression(this.get('name')),
        desc;

    if(Discourse.User.currentProp("admin") || Discourse.User.currentProp("moderator")) {
      if(this.get('admin')) {
        desc = I18n.t('user.admin', {user: name});
        return '<i class="fa fa-shield" title="' + desc +  '" alt="' + desc + '"></i>';
      }
    }
    if(this.get('moderator')){
      desc = I18n.t('user.moderator', {user: name});
      return '<i class="fa fa-shield" title="' + desc +  '" alt="' + desc + '"></i>';
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

  isBasic: Em.computed.equal('trust_level', 0),
  isLeader: Em.computed.equal('trust_level', 3),
  isElder: Em.computed.equal('trust_level', 4),
  canManageTopic: Em.computed.or('staff', 'isElder'),

  isSuspended: Em.computed.equal('suspended', true),

  suspended: function() {
    return this.get('suspended_till') && moment(this.get('suspended_till')).isAfter();
  }.property('suspended_till'),

  suspendedTillDate: function() {
    return Discourse.Formatter.longDate(this.get('suspended_till'));
  }.property('suspended_till'),

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
    var self = this,
        data = this.getProperties('auto_track_topics_after_msecs',
                               'bio_raw',
                               'website',
                               'location',
                               'name',
                               'locale',
                               'email_digests',
                               'email_direct',
                               'email_always',
                               'email_private_messages',
                               'dynamic_favicon',
                               'digest_after_days',
                               'new_topic_duration_minutes',
                               'external_links_in_new_tab',
                               'mailing_list_mode',
                               'enable_quoting',
                               'disable_jump_reply',
                               'custom_fields',
                               'user_fields');

    ['muted','watched','tracked'].forEach(function(s){
      var cats = self.get(s + 'Categories').map(function(c){ return c.get('id')});
      // HACK: denote lack of categories
      if(cats.length === 0) { cats = [-1]; }
      data[s + '_category_ids'] = cats;
    });

    if (!Discourse.SiteSettings.edit_history_visible_to_public) {
      data['edit_history_public'] = this.get('edit_history_public');
    }

    return Discourse.ajax("/users/" + this.get('username_lower'), {
      data: data,
      type: 'PUT'
    }).then(function(data) {
      self.set('bio_excerpt',data.user.bio_excerpt);

      var userProps = self.getProperties('enable_quoting', 'external_links_in_new_tab', 'dynamic_favicon');
      Discourse.User.current().setProperties(userProps);
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
    var self = this,
        stream = this.get('stream');
    return Discourse.ajax("/user_actions/" + id + ".json", { cache: 'false' }).then(function(result) {
      if (result && result.user_action) {
        var ua = result.user_action;

        if ((self.get('stream.filter') || ua.action_type) !== ua.action_type) return;
        if (!self.get('stream.filter') && !self.inAllStream(ua)) return;

        var action = Discourse.UserAction.collapseStream([Discourse.UserAction.create(ua)]);
        stream.set('itemsLoaded', stream.get('itemsLoaded') + 1);
        stream.get('content').insertAt(0, action[0]);
      }
    });
  },

  inAllStream: function(ua) {
    return ua.action_type === Discourse.UserAction.TYPES.posts ||
           ua.action_type === Discourse.UserAction.TYPES.topics;
  },

  /**
  The user's stat count, excluding PMs.

    @property statsCountNonPM
    @type {Integer}
  **/
  statsCountNonPM: function() {
    var self = this;

    if (this.blank('statsExcludingPms')) return 0;
    var count = 0;
    _.each(this.get('statsExcludingPms'), function(val) {
      if (self.inAllStream(val)){
        count += val.count;
      }
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

      if (!Em.isEmpty(json.user.custom_groups)) {
        json.user.custom_groups = json.user.custom_groups.map(function (g) {
          return Discourse.Group.create(g);
        });
      }

      if (json.user.invited_by) {
        json.user.invited_by = Discourse.User.create(json.user.invited_by);
      }

      if (!Em.isEmpty(json.user.featured_user_badge_ids)) {
        var userBadgesMap = {};
        Discourse.UserBadge.createFromJson(json).forEach(function(userBadge) {
          userBadgesMap[ userBadge.get('id') ] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids.map(function(id) {
          return userBadgesMap[id];
        });
      }

      if (json.user.card_badge) {
        json.user.card_badge = Discourse.Badge.create(json.user.card_badge);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  avatarTemplate: function() {
    return Discourse.User.avatarTemplate(this.get('username'), this.get('uploaded_avatar_id'));
  }.property('uploaded_avatar_id', 'username'),

  /*
    Change avatar selection
  */
  pickAvatar: function(uploadId) {
    this.set("uploaded_avatar_id", uploadId);
    return Discourse.ajax("/users/" + this.get("username_lower") + "/preferences/avatar/pick", {
      type: 'PUT',
      data: { upload_id: uploadId }
    });
  },

  /**
    Determines whether the current user is allowed to upload a file.

    @method isAllowedToUploadAFile
    @param {String} type The type of the upload (image, attachment)
    @returns true if the current user is allowed to upload a file
  **/
  isAllowedToUploadAFile: function(type) {
    return this.get('staff') ||
           this.get('trust_level') > 0 ||
           Discourse.SiteSettings['newuser_max_' + type + 's'] > 0;
  },

  /**
    Invite a user to the site

    @method createInvite
    @param {String} email The email address of the user to invite to the site
    @returns {Promise} the result of the server call
  **/
  createInvite: function(email, groupNames) {
    return Discourse.ajax('/invites', {
      type: 'POST',
      data: {email: email, group_names: groupNames}
    });
  },

  updateMutedCategories: function() {
    this.set("mutedCategories", Discourse.Category.findByIds(this.muted_category_ids));
  }.observes("muted_category_ids"),

  updateTrackedCategories: function() {
    this.set("trackedCategories", Discourse.Category.findByIds(this.tracked_category_ids));
  }.observes("tracked_category_ids"),

  updateWatchedCategories: function() {
    this.set("watchedCategories", Discourse.Category.findByIds(this.watched_category_ids));
  }.observes("watched_category_ids"),

  canDeleteAccount: function() {
    return this.get('can_delete_account') && ((this.get('reply_count')||0) + (this.get('topic_count')||0)) <= 1;
  }.property('can_delete_account', 'reply_count', 'topic_count'),

  "delete": function() {
    if (this.get('can_delete_account')) {
      return Discourse.ajax("/users/" + this.get('username'), {
        type: 'DELETE',
        data: {context: window.location.pathname}
      });
    } else {
      return Ember.RSVP.reject(I18n.t('user.delete_yourself_not_allowed'));
    }
  },

  dismissBanner: function (bannerKey) {
    this.set("dismissed_banner_key", bannerKey);
    Discourse.ajax("/users/" + this.get('username'), {
      type: 'PUT',
      data: { dismissed_banner_key: bannerKey }
    });
  },

  checkEmail: function () {
    var self = this;
    return Discourse.ajax("/users/" + this.get("username_lower") + "/emails.json", {
      type: "PUT",
      data: { context: window.location.pathname }
    }).then(function (result) {
      if (result) {
        self.setProperties({
          email: result.email,
          associated_accounts: result.associated_accounts
        });
      }
    }, function () {});
  }

});

Discourse.User.reopenClass(Discourse.Singleton, {

  avatarTemplate: function(username, uploadedAvatarId) {
    var url;
    if (uploadedAvatarId) {
      url = "/user_avatar/" +
            Discourse.BaseUrl +
            "/" +
            username.toLowerCase() +
            "/{size}/" +
            uploadedAvatarId + ".png";
    } else {
      url = "/letter_avatar/" +
            username.toLowerCase() +
            "/{size}/" +
            Discourse.LetterAvatarVersion + ".png";
    }

    url = Discourse.getURL(url);
    if (Discourse.CDN) {
      url = Discourse.CDN + url;
    }
    return url;
  },

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
    @param {Number} forUserId user id - provide when changing username
  **/
  checkUsername: function(username, email, forUserId) {
    return Discourse.ajax('/users/check_username', {
      data: { username: username, email: email, for_user_id: forUserId }
    });
  },

  /**
    Groups the user's statistics

    @method groupStats
    @param {Array} stats Given stats
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
    Creates a new account
  **/
  createAccount: function(attrs) {
    return Discourse.ajax("/users", {
      data: {
        name: attrs.accountName,
        email: attrs.accountEmail,
        password: attrs.accountPassword,
        username: attrs.accountUsername,
        password_confirmation: attrs.accountPasswordConfirm,
        challenge: attrs.accountChallenge,
        user_fields: attrs.userFields
      },
      type: 'POST'
    });
  }
});
