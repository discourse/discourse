import { url } from 'discourse/lib/computed';
import RestModel from 'discourse/models/rest';
import avatarTemplate from 'discourse/lib/avatar-template';
import UserStream from 'discourse/models/user-stream';
import UserPostsStream from 'discourse/models/user-posts-stream';
import Singleton from 'discourse/mixins/singleton';
import { longDate } from 'discourse/lib/formatter';
import computed from 'ember-addons/ember-computed-decorators';
import Badge from 'discourse/models/badge';
import UserBadge from 'discourse/models/user-badge';

const User = RestModel.extend({

  hasPMs: Em.computed.gt("private_messages_stats.all", 0),
  hasStartedPMs: Em.computed.gt("private_messages_stats.mine", 0),
  hasUnreadPMs: Em.computed.gt("private_messages_stats.unread", 0),
  hasPosted: Em.computed.gt("post_count", 0),
  hasNotPosted: Em.computed.not("hasPosted"),
  canBeDeleted: Em.computed.and("can_be_deleted", "hasNotPosted"),

  stream: function() {
    return UserStream.create({ user: this });
  }.property(),

  postsStream: function() {
    return UserPostsStream.create({ user: this });
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
    if (Discourse.SiteSettings.enable_names && !Ember.isEmpty(this.get('name'))) {
      return this.get('name');
    }
    return this.get('username');
  }.property('username', 'name'),

  @computed('profile_background')
  profileBackground(bgUrl) {
    if (Em.isEmpty(bgUrl) || !Discourse.SiteSettings.allow_profile_backgrounds) { return; }
    return ('background-image: url(' + Discourse.getURLWithCDN(bgUrl) + ')').htmlSafe();
  },

  /**
    Path to this user.

    @property path
    @type {String}
  **/
  path: function(){
    return Discourse.getURL('/users/' + this.get('username_lower'));
    // no need to observe, requires a hard refresh to update
  }.property(),

  /**
    Path to this user's administration

    @property adminPath
    @type {String}
  **/
  adminPath: url('username_lower', "/admin/users/%@"),

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
    return longDate(this.get('suspended_till'));
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
    const self = this,
          data = this.getProperties(
            'auto_track_topics_after_msecs',
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
            'user_fields',
            'muted_usernames',
            'profile_background',
            'card_background'
          );

    ['muted','watched','tracked'].forEach(function(s){
      var cats = self.get(s + 'Categories').map(function(c){ return c.get('id')});
      // HACK: denote lack of categories
      if(cats.length === 0) { cats = [-1]; }
      data[s + '_category_ids'] = cats;
    });

    if (!Discourse.SiteSettings.edit_history_visible_to_public) {
      data['edit_history_public'] = this.get('edit_history_public');
    }

    // TODO: We can remove this when migrated fully to rest model.
    this.set('isSaving', true);
    return Discourse.ajax("/users/" + this.get('username_lower'), {
      data: data,
      type: 'PUT'
    }).then(function(result) {
      self.set('bio_excerpt', result.user.bio_excerpt);

      const userProps = self.getProperties('enable_quoting', 'external_links_in_new_tab', 'dynamic_favicon');
      Discourse.User.current().setProperties(userProps);
    }).finally(() => {
      this.set('isSaving', false);
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

  // The user's stat count, excluding PMs.
  statsCountNonPM: function() {
    var self = this;

    if (Ember.isEmpty(this.get('statsExcludingPms'))) return 0;
    var count = 0;
    _.each(this.get('statsExcludingPms'), function(val) {
      if (self.inAllStream(val)){
        count += val.count;
      }
    });
    return count;
  }.property('statsExcludingPms.@each.count'),

  // The user's stats, excluding PMs.
  statsExcludingPms: function() {
    if (Ember.isEmpty(this.get('stats'))) return [];
    return this.get('stats').rejectProperty('isPM');
  }.property('stats.@each.isPM'),

  findDetails: function(options) {
    var user = this;

    return PreloadStore.getAndRemove("user_" + user.get('username'), function() {
      return Discourse.ajax("/users/" + user.get('username') + '.json', {data: options});
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
        const userBadgesMap = {};
        UserBadge.createFromJson(json).forEach(function(userBadge) {
          userBadgesMap[ userBadge.get('id') ] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids.map(function(id) {
          return userBadgesMap[id];
        });
      }

      if (json.user.card_badge) {
        json.user.card_badge = Badge.create(json.user.card_badge);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  findStaffInfo: function() {
    if (!Discourse.User.currentProp("staff")) { return Ember.RSVP.resolve(null); }
    var self = this;
    return Discourse.ajax("/users/" + this.get("username_lower") + "/staff-info.json").then(function(info) {
      self.setProperties(info);
    });
  },

  avatarTemplate: function() {
    return avatarTemplate(this.get('username'), this.get('uploaded_avatar_id'));
  }.property('uploaded_avatar_id', 'username'),

  /*
    Change avatar selection
  */
  pickAvatar: function(uploadId) {
    var self = this;

    return Discourse.ajax("/users/" + this.get("username_lower") + "/preferences/avatar/pick", {
      type: 'PUT',
      data: { upload_id: uploadId }
    }).then(function(){
      self.set('uploaded_avatar_id', uploadId);
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
    return !Discourse.SiteSettings.enable_sso && this.get('can_delete_account') && ((this.get('reply_count')||0) + (this.get('topic_count')||0)) <= 1;
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

User.reopenClass(Singleton, {

  // Find a `Discourse.User` for a given username.
  findByUsername: function(username, options) {
    const user = User.create({username: username});
    return user.findDetails(options);
  },

  // TODO: Use app.register and junk Singleton
  createCurrent: function() {
    var userJson = PreloadStore.get('currentUser');
    if (userJson) {
      const store = Discourse.__container__.lookup('store:main');
      return store.createRecord('user', userJson);
    }
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

export default User;
