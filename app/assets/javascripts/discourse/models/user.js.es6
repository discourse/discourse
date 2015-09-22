import { url } from 'discourse/lib/computed';
import RestModel from 'discourse/models/rest';
import UserStream from 'discourse/models/user-stream';
import UserPostsStream from 'discourse/models/user-posts-stream';
import Singleton from 'discourse/mixins/singleton';
import { longDate } from 'discourse/lib/formatter';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import Badge from 'discourse/models/badge';
import UserBadge from 'discourse/models/user-badge';

const User = RestModel.extend({

  hasPMs: Em.computed.gt("private_messages_stats.all", 0),
  hasStartedPMs: Em.computed.gt("private_messages_stats.mine", 0),
  hasUnreadPMs: Em.computed.gt("private_messages_stats.unread", 0),
  hasPosted: Em.computed.gt("post_count", 0),
  hasNotPosted: Em.computed.not("hasPosted"),
  canBeDeleted: Em.computed.and("can_be_deleted", "hasNotPosted"),

  @computed()
  stream() {
    return UserStream.create({ user: this });
  },

  @computed()
  postsStream() {
    return UserPostsStream.create({ user: this });
  },

  staff: Em.computed.or('admin', 'moderator'),

  destroySession() {
    return Discourse.ajax(`/session/${this.get('username')}`, { type: 'DELETE'});
  },

  @computed("username_lower")
  searchContext(username) {
    return {
      type: 'user',
      id: username,
      user: this
    };
  },

  @computed("username", "name")
  displayName(username, name) {
    if (Discourse.SiteSettings.enable_names && !Ember.isEmpty(name)) {
      return name;
    }
    return username;
  },

  @computed('profile_background')
  profileBackground(bgUrl) {
    if (Em.isEmpty(bgUrl) || !Discourse.SiteSettings.allow_profile_backgrounds) { return; }
    return ('background-image: url(' + Discourse.getURLWithCDN(bgUrl) + ')').htmlSafe();
  },

  @computed()
  path() {
    // no need to observe, requires a hard refresh to update
    return Discourse.getURL(`/users/${this.get('username_lower')}`);
  },

  adminPath: url('username_lower', "/admin/users/%@"),

  @computed("username")
  username_lower(username) {
    return username.toLowerCase();
  },

  @computed("trust_level")
  trustLevel(trustLevel) {
    return Discourse.Site.currentProp('trustLevels').findProperty('id', parseInt(trustLevel, 10));
  },

  isBasic: Em.computed.equal('trust_level', 0),
  isLeader: Em.computed.equal('trust_level', 3),
  isElder: Em.computed.equal('trust_level', 4),
  canManageTopic: Em.computed.or('staff', 'isElder'),

  isSuspended: Em.computed.equal('suspended', true),

  @computed("suspended_till")
  suspended(suspendedTill) {
    return suspendedTill && moment(suspendedTill).isAfter();
  },

  @computed("suspended_till")
  suspendedTillDate(suspendedTill) {
    return longDate(suspendedTill);
  },

  changeUsername(new_username) {
    return Discourse.ajax(`/users/${this.get('username_lower')}/preferences/username`, {
      type: 'PUT',
      data: { new_username }
    });
  },

  changeEmail(email) {
    return Discourse.ajax(`/users/${this.get('username_lower')}/preferences/email`, {
      type: 'PUT',
      data: { email }
    });
  },

  copy() {
    return Discourse.User.create(this.getProperties(Ember.keys(this)));
  },

  save() {
    const data = this.getProperties(
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

    ['muted','watched','tracked'].forEach(s => {
      let cats = this.get(s + 'Categories').map(c => c.get('id'));
      // HACK: denote lack of categories
      if (cats.length === 0) { cats = [-1]; }
      data[s + '_category_ids'] = cats;
    });

    if (!Discourse.SiteSettings.edit_history_visible_to_public) {
      data['edit_history_public'] = this.get('edit_history_public');
    }

    // TODO: We can remove this when migrated fully to rest model.
    this.set('isSaving', true);
    return Discourse.ajax(`/users/${this.get('username_lower')}`, {
      data: data,
      type: 'PUT'
    }).then(result => {
      this.set('bio_excerpt', result.user.bio_excerpt);
      const userProps = this.getProperties('enable_quoting', 'external_links_in_new_tab', 'dynamic_favicon');
      Discourse.User.current().setProperties(userProps);
    }).finally(() => {
      this.set('isSaving', false);
    });
  },

  changePassword() {
    return Discourse.ajax("/session/forgot_password", {
      dataType: 'json',
      data: { login: this.get('username') },
      type: 'POST'
    });
  },

  loadUserAction(id) {
    const stream = this.get('stream');
    return Discourse.ajax(`/user_actions/${id}.json`, { cache: 'false' }).then(result => {
      if (result && result.user_action) {
        const ua = result.user_action;

        if ((this.get('stream.filter') || ua.action_type) !== ua.action_type) return;
        if (!this.get('stream.filter') && !this.inAllStream(ua)) return;

        const action = Discourse.UserAction.collapseStream([Discourse.UserAction.create(ua)]);
        stream.set('itemsLoaded', stream.get('itemsLoaded') + 1);
        stream.get('content').insertAt(0, action[0]);
      }
    });
  },

  inAllStream(ua) {
    return ua.action_type === Discourse.UserAction.TYPES.posts ||
           ua.action_type === Discourse.UserAction.TYPES.topics;
  },

  // The user's stat count, excluding PMs.
  @computed("statsExcludingPms.@each.count")
  statsCountNonPM() {
    if (Ember.isEmpty(this.get('statsExcludingPms'))) return 0;
    let count = 0;
    _.each(this.get('statsExcludingPms'), val => {
      if (this.inAllStream(val)) {
        count += val.count;
      }
    });
    return count;
  },

  // The user's stats, excluding PMs.
  @computed("stats.@each.isPM")
  statsExcludingPms() {
    if (Ember.isEmpty(this.get('stats'))) return [];
    return this.get('stats').rejectProperty('isPM');
  },

  findDetails(options) {
    const user = this;

    return PreloadStore.getAndRemove(`user_${user.get('username')}`, () => {
      return Discourse.ajax(`/users/${user.get('username')}.json`, { data: options });
    }).then(json => {

      if (!Em.isEmpty(json.user.stats)) {
        json.user.stats = Discourse.User.groupStats(_.map(json.user.stats, s => {
          if (s.count) s.count = parseInt(s.count, 10);
          return Discourse.UserActionStat.create(s);
        }));
      }

      if (!Em.isEmpty(json.user.custom_groups)) {
        json.user.custom_groups = json.user.custom_groups.map(g => Discourse.Group.create(g));
      }

      if (json.user.invited_by) {
        json.user.invited_by = Discourse.User.create(json.user.invited_by);
      }

      if (!Em.isEmpty(json.user.featured_user_badge_ids)) {
        const userBadgesMap = {};
        UserBadge.createFromJson(json).forEach(userBadge => {
          userBadgesMap[ userBadge.get('id') ] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids.map(id => userBadgesMap[id]);
      }

      if (json.user.card_badge) {
        json.user.card_badge = Badge.create(json.user.card_badge);
      }

      user.setProperties(json.user);
      return user;
    });
  },

  findStaffInfo() {
    if (!Discourse.User.currentProp("staff")) { return Ember.RSVP.resolve(null); }
    return Discourse.ajax(`/users/${this.get("username_lower")}/staff-info.json`).then(info => {
      this.setProperties(info);
    });
  },

  pickAvatar(upload_id, type, avatar_template) {
    return Discourse.ajax(`/users/${this.get("username_lower")}/preferences/avatar/pick`, {
      type: 'PUT',
      data: { upload_id, type }
    }).then(() => this.setProperties({
      avatar_template,
      uploaded_avatar_id: upload_id
    }));
  },

  isAllowedToUploadAFile(type) {
    return this.get('staff') ||
           this.get('trust_level') > 0 ||
           Discourse.SiteSettings['newuser_max_' + type + 's'] > 0;
  },

  createInvite(email, group_names) {
    return Discourse.ajax('/invites', {
      type: 'POST',
      data: { email, group_names }
    });
  },

  generateInviteLink(email, group_names, topic_id) {
    return Discourse.ajax('/invites/link', {
      type: 'POST',
      data: { email, group_names, topic_id }
    });
  },

  @observes("muted_category_ids")
  updateMutedCategories() {
    this.set("mutedCategories", Discourse.Category.findByIds(this.muted_category_ids));
  },

  @observes("tracked_category_ids")
  updateTrackedCategories() {
    this.set("trackedCategories", Discourse.Category.findByIds(this.tracked_category_ids));
  },

  @observes("watched_category_ids")
  updateWatchedCategories() {
    this.set("watchedCategories", Discourse.Category.findByIds(this.watched_category_ids));
  },

  @computed("can_delete_account", "reply_count", "topic_count")
  canDeleteAccount(canDeleteAccount, replyCount, topicCount) {
    return !Discourse.SiteSettings.enable_sso && canDeleteAccount && ((replyCount || 0) + (topicCount || 0)) <= 1;
  },

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

  dismissBanner(bannerKey) {
    this.set("dismissed_banner_key", bannerKey);
    Discourse.ajax(`/users/${this.get('username')}`, {
      type: 'PUT',
      data: { dismissed_banner_key: bannerKey }
    });
  },

  checkEmail() {
    return Discourse.ajax(`/users/${this.get("username_lower")}/emails.json`, {
      type: "PUT",
      data: { context: window.location.pathname }
    }).then(result => {
      if (result) {
        this.setProperties({
          email: result.email,
          associated_accounts: result.associated_accounts
        });
      }
    });
  }

});

User.reopenClass(Singleton, {

  // Find a `Discourse.User` for a given username.
  findByUsername(username, options) {
    const user = User.create({username: username});
    return user.findDetails(options);
  },

  // TODO: Use app.register and junk Singleton
  createCurrent() {
    const userJson = PreloadStore.get('currentUser');
    if (userJson) {
      const store = Discourse.__container__.lookup('store:main');
      return store.createRecord('user', userJson);
    }
    return null;
  },

  checkUsername(username, email, for_user_id) {
    return Discourse.ajax('/users/check_username', {
      data: { username, email, for_user_id }
    });
  },

  groupStats(stats) {
    const responses = Discourse.UserActionStat.create({
      count: 0,
      action_type: Discourse.UserAction.TYPES.replies
    });

    stats.filterProperty('isResponse').forEach(stat => {
      responses.set('count', responses.get('count') + stat.get('count'));
    });

    const result = Em.A();
    result.pushObjects(stats.rejectProperty('isResponse'));

    let insertAt = 0;
    result.forEach((item, index) => {
     if (item.action_type === Discourse.UserAction.TYPES.topics || item.action_type === Discourse.UserAction.TYPES.posts) {
       insertAt = index + 1;
     }
    });
    if (responses.count > 0) {
      result.insertAt(insertAt, responses);
    }
    return result;
  },

  createAccount(attrs) {
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
