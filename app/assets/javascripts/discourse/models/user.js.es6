import { ajax } from 'discourse/lib/ajax';
import { url } from 'discourse/lib/computed';
import RestModel from 'discourse/models/rest';
import UserStream from 'discourse/models/user-stream';
import UserPostsStream from 'discourse/models/user-posts-stream';
import Singleton from 'discourse/mixins/singleton';
import { longDate } from 'discourse/lib/formatter';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import Badge from 'discourse/models/badge';
import UserBadge from 'discourse/models/user-badge';
import UserActionStat from 'discourse/models/user-action-stat';
import UserAction from 'discourse/models/user-action';
import Group from 'discourse/models/group';
import { emojiUnescape } from 'discourse/lib/text';
import PreloadStore from 'preload-store';
import { defaultHomepage } from 'discourse/lib/utilities';
import { userPath } from 'discourse/lib/url';

const isForever = dt => moment().diff(dt, 'years') < -500;

const User = RestModel.extend({

  hasPMs: Em.computed.gt("private_messages_stats.all", 0),
  hasStartedPMs: Em.computed.gt("private_messages_stats.mine", 0),
  hasUnreadPMs: Em.computed.gt("private_messages_stats.unread", 0),
  hasPosted: Em.computed.gt("post_count", 0),
  hasNotPosted: Em.computed.not("hasPosted"),
  canBeDeleted: Em.computed.and("can_be_deleted", "hasNotPosted"),

  redirected_to_top: {
    reason: null,
  },

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
    return ajax(`/session/${this.get('username')}`, { type: 'DELETE'});
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
    if (Em.isEmpty(bgUrl) || !Discourse.SiteSettings.allow_profile_backgrounds) { return "".htmlSafe(); }
    return ('background-image: url(' + Discourse.getURLWithCDN(bgUrl) + ')').htmlSafe();
  },

  @computed()
  path() {
    // no need to observe, requires a hard refresh to update
    return userPath(this.get('username_lower'));
  },

  @computed()
  userApiKeys() {
    const keys = this.get('user_api_keys');
    if (keys) {
      return keys.map((raw)=>{
        let obj = Em.Object.create(
          raw
        );

        obj.revoke = () => {
          this.revokeApiKey(obj);
        };

        obj.undoRevoke = () => {
          this.undoRevokeApiKey(obj);
        };

        return obj;
      });
    }
  },

  revokeApiKey(key) {
    return ajax("/user-api-key/revoke", {
      type: 'POST',
      data: { id: key.get('id') }
    }).then(()=>{
      key.set('revoked', true);
    });
  },

  undoRevokeApiKey(key){
    return ajax("/user-api-key/undo-revoke", {
      type: 'POST',
      data: { id: key.get('id') }
    }).then(()=>{
      key.set('revoked', false);
    });
  },

  pmPath(topic) {
    const userId = this.get('id');
    const username = this.get('username_lower');

    const details = topic && topic.get('details');
    const allowedUsers = details && details.get('allowed_users');
    const groups = details && details.get('allowed_groups');

    // directly targetted so go to inbox
    if (!groups || (allowedUsers && allowedUsers.findBy("id", userId))) {
      return userPath(`${username}/messages`);
    } else {
      if (groups && groups[0]) {
        return userPath(`${username}/messages/group/${groups[0].name}`);
      }
    }

  },

  adminPath: url('id', 'username_lower', "/admin/users/%@1/%@2"),

  @computed()
  mutedTopicsPath() {
    return defaultHomepage() === "latest" ? Discourse.getURL('/?state=muted') : Discourse.getURL('/latest?state=muted');
  },

  @computed()
  watchingTopicsPath() {
    return defaultHomepage() === "latest" ? Discourse.getURL('/?state=watching') : Discourse.getURL('/latest?state=watching');
  },

  @computed()
  trackingTopicsPath() {
    return defaultHomepage() === "latest" ? Discourse.getURL('/?state=tracking') : Discourse.getURL('/latest?state=tracking');
  },

  @computed("username")
  username_lower(username) {
    return username.toLowerCase();
  },

  @computed("trust_level")
  trustLevel(trustLevel) {
    return Discourse.Site.currentProp('trustLevels').findBy('id', parseInt(trustLevel, 10));
  },

  isBasic: Em.computed.equal('trust_level', 0),
  isLeader: Em.computed.equal('trust_level', 3),
  isElder: Em.computed.equal('trust_level', 4),
  canManageTopic: Em.computed.or('staff', 'isElder'),

  isSuspended: Em.computed.equal('suspended', true),

  @computed("previous_visit_at")
  previousVisitAt(previous_visit_at) {
    return new Date(previous_visit_at);
  },

  @computed("suspended_till")
  suspended(suspendedTill) {
    return suspendedTill && moment(suspendedTill).isAfter();
  },

  @computed("suspended_till")
  suspendedForever: isForever,

  @computed("silenced_till")
  silencedForever: isForever,

  @computed("suspended_till")
  suspendedTillDate: longDate,

  @computed("silenced_till")
  silencedTillDate: longDate,

  changeUsername(new_username) {
    return ajax(userPath(`${this.get('username_lower')}/preferences/username`), {
      type: 'PUT',
      data: { new_username }
    });
  },

  changeEmail(email) {
    return ajax(userPath(`${this.get('username_lower')}/preferences/email`), {
      type: 'PUT',
      data: { email }
    });
  },

  copy() {
    return Discourse.User.create(this.getProperties(Object.keys(this)));
  },

  save(fields) {

    let userFields = [
      'bio_raw',
      'website',
      'location',
      'name',
      'locale',
      'custom_fields',
      'user_fields',
      'muted_usernames',
      'profile_background',
      'card_background',
      'muted_tags',
      'tracked_tags',
      'watched_tags',
      'watching_first_post_tags',
      'date_of_birth'
    ];

    const data = this.getProperties(fields ? _.intersection(userFields, fields) : userFields);

    let userOptionFields = [
      'email_always',
      'mailing_list_mode',
      'mailing_list_mode_frequency',
      'external_links_in_new_tab',
      'email_digests',
      'email_direct',
      'email_in_reply_to',
      'email_private_messages',
      'email_previous_replies',
      'dynamic_favicon',
      'enable_quoting',
      'disable_jump_reply',
      'automatically_unpin_topics',
      'digest_after_minutes',
      'new_topic_duration_minutes',
      'auto_track_topics_after_msecs',
      'notification_level_when_replying',
      'like_notification_frequency',
      'include_tl0_in_digests',
      'theme_key',
      'allow_private_messages',
      'homepage_id',
    ];

    if (fields) {
      userOptionFields = _.intersection(userOptionFields, fields);
    }

    userOptionFields.forEach(s => {
      data[s] = this.get(`user_option.${s}`);
    });

    var updatedState = {};

    ['muted','watched','tracked','watched_first_post'].forEach(s => {
      if (fields === undefined || fields.includes(s + '_category_ids')) {
        let prop = s === "watched_first_post" ? "watchedFirstPostCategories" : s + "Categories";
        let cats = this.get(prop);
        if (cats) {
          let cat_ids = cats.map(c => c.get('id'));
          updatedState[s + '_category_ids'] = cat_ids;

          // HACK: denote lack of categories
          if (cats.length === 0) { cat_ids = [-1]; }
          data[s + '_category_ids'] = cat_ids;
        }
      }
    });

    // TODO: We can remove this when migrated fully to rest model.
    this.set('isSaving', true);
    return ajax(userPath(`${this.get('username_lower')}.json`), {
      data: data,
      type: 'PUT'
    }).then(result => {
      this.set('bio_excerpt', result.user.bio_excerpt);
      const userProps = Em.getProperties(this.get('user_option'),'enable_quoting', 'external_links_in_new_tab', 'dynamic_favicon');
      Discourse.User.current().setProperties(userProps);
      this.setProperties(updatedState);
    }).finally(() => {
      this.set('isSaving', false);
    });
  },

  changePassword() {
    return ajax("/session/forgot_password", {
      dataType: 'json',
      data: { login: this.get('username') },
      type: 'POST'
    });
  },

  loadUserAction(id) {
    const stream = this.get('stream');
    return ajax(`/user_actions/${id}.json`, { cache: 'false' }).then(result => {
      if (result && result.user_action) {
        const ua = result.user_action;

        if ((this.get('stream.filter') || ua.action_type) !== ua.action_type) return;
        if (!this.get('stream.filter') && !this.inAllStream(ua)) return;

        ua.title = emojiUnescape(Handlebars.Utils.escapeExpression(ua.title));
        const action = UserAction.collapseStream([UserAction.create(ua)]);
        stream.set('itemsLoaded', stream.get('itemsLoaded') + 1);
        stream.get('content').insertAt(0, action[0]);
      }
    });
  },

  inAllStream(ua) {
    return ua.action_type === UserAction.TYPES.posts ||
           ua.action_type === UserAction.TYPES.topics;
  },

  @computed("groups.[]")
  displayGroups() {
    const groups = this.get('groups') || [];
    const filtered = groups.filter(group => {
      return !group.automatic || group.name === "moderators";
    });
    return filtered.length === 0 ? null : filtered;
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
    return this.get('stats').rejectBy('isPM');
  },

  findDetails(options) {
    const user = this;

    return PreloadStore.getAndRemove(`user_${user.get('username')}`, () => {
      return ajax(userPath(`${user.get('username')}.json`), { data: options });
    }).then(json => {

      if (!Em.isEmpty(json.user.stats)) {
        json.user.stats = Discourse.User.groupStats(_.map(json.user.stats, s => {
          if (s.count) s.count = parseInt(s.count, 10);
          return UserActionStat.create(s);
        }));
      }

      if (!Em.isEmpty(json.user.groups)) {
        const groups = [];

        for(let i = 0; i < json.user.groups.length; i++) {
          const group = Group.create(json.user.groups[i]);
          group.group_user = json.user.group_users[i];
          groups.push(group);
        }

        json.user.groups = groups;
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
    return ajax(userPath(`${this.get("username_lower")}/staff-info.json`)).then(info => {
      this.setProperties(info);
    });
  },

  pickAvatar(upload_id, type, avatar_template) {
    return ajax(userPath(`${this.get("username_lower")}/preferences/avatar/pick`), {
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

  createInvite(email, group_names, custom_message) {
    return ajax('/invites', {
      type: 'POST',
      data: { email, group_names, custom_message }
    });
  },

  generateInviteLink(email, group_names, topic_id) {
    return ajax('/invites/link', {
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

  @observes("watched_first_post_category_ids")
  updateWatchedFirstPostCategories() {
    this.set("watchedFirstPostCategories", Discourse.Category.findByIds(this.watched_first_post_category_ids));
  },

  @computed("can_delete_account", "reply_count", "topic_count")
  canDeleteAccount(canDeleteAccount, replyCount, topicCount) {
    return !Discourse.SiteSettings.enable_sso && canDeleteAccount && ((replyCount || 0) + (topicCount || 0)) <= 1;
  },

  "delete": function() {
    if (this.get('can_delete_account')) {
      return ajax(userPath(this.get('username') + ".json"), {
        type: 'DELETE',
        data: {context: window.location.pathname}
      });
    } else {
      return Ember.RSVP.reject(I18n.t('user.delete_yourself_not_allowed'));
    }
  },

  dismissBanner(bannerKey) {
    this.set("dismissed_banner_key", bannerKey);
    ajax(userPath(this.get('username') + ".json"), {
      type: 'PUT',
      data: { dismissed_banner_key: bannerKey }
    });
  },

  checkEmail() {
    return ajax(userPath(`${this.get("username_lower")}/emails.json`), {
      data: { context: window.location.pathname }
    }).then(result => {
      if (result) {
        this.setProperties({
          email: result.email,
          associated_accounts: result.associated_accounts
        });
      }
    });
  },

  summary() {
    let { store } = this;

    return ajax(userPath(`${this.get("username_lower")}/summary.json`)).then(json => {
      const summary = json.user_summary;
      const topicMap = {};
      const badgeMap = {};

      json.topics.forEach(t => topicMap[t.id] = store.createRecord('topic', t));
      Badge.createFromJson(json).forEach(b => badgeMap[b.id] = b );

      summary.topics = summary.topic_ids.map(id => topicMap[id]);

      summary.replies.forEach(r => {
        r.topic = topicMap[r.topic_id];
        r.url = r.topic.urlForPostNumber(r.post_number);
        r.createdAt = new Date(r.created_at);
      });

      summary.links.forEach(l => {
        l.topic = topicMap[l.topic_id];
        l.post_url = l.topic.urlForPostNumber(l.post_number);
      });

      if (summary.badges) {
        summary.badges = summary.badges.map(ub => {
          const badge = badgeMap[ub.badge_id];
          badge.count = ub.count;
          return badge;
        });
      }

      return summary;
    });
  },

  canManageGroup(group) {
    return group.get('automatic') ? false : (this.get('admin') || group.get('is_group_owner'));
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
      const store = Discourse.__container__.lookup('service:store');
      return store.createRecord('user', userJson);
    }
    return null;
  },

  checkUsername(username, email, for_user_id) {
    return ajax(userPath('check_username'), {
      data: { username, email, for_user_id }
    });
  },

  groupStats(stats) {
    const responses = UserActionStat.create({
      count: 0,
      action_type: UserAction.TYPES.replies
    });

    stats.filterBy('isResponse').forEach(stat => {
      responses.set('count', responses.get('count') + stat.get('count'));
    });

    const result = Em.A();
    result.pushObjects(stats.rejectBy('isResponse'));

    let insertAt = 0;
    result.forEach((item, index) => {
     if (item.action_type === UserAction.TYPES.topics || item.action_type === UserAction.TYPES.posts) {
       insertAt = index + 1;
     }
    });
    if (responses.count > 0) {
      result.insertAt(insertAt, responses);
    }
    return result;
  },

  createAccount(attrs) {
    return ajax(userPath(), {
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
