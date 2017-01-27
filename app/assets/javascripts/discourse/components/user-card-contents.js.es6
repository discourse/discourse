import { wantsNewWindow } from 'discourse/lib/intercept-click';
import { propertyNotEqual, setting } from 'discourse/lib/computed';
import CleansUp from 'discourse/mixins/cleans-up';
import afterTransition from 'discourse/lib/after-transition';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import DiscourseURL from 'discourse/lib/url';
import User from 'discourse/models/user';

const clickOutsideEventName = "mousedown.outside-user-card";
const clickDataExpand = "click.discourse-user-card";
const clickMention = "click.discourse-user-mention";

export default Ember.Component.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['visible:show', 'showBadges', 'hasCardBadgeImage', 'user.card_background::no-bg'],
  allowBackgrounds: setting('allow_profile_backgrounds'),

  postStream: Ember.computed.alias('topic.postStream'),
  enoughPostsForFiltering: Ember.computed.gte('topicPostCount', 2),
  viewingTopic: Ember.computed.match('currentPath', /^topic\./),
  viewingAdmin: Ember.computed.match('currentPath', /^admin\./),
  showFilter: Ember.computed.and('viewingTopic', 'postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: propertyNotEqual('user.name', 'user.username'),
  hasUserFilters: Ember.computed.gt('postStream.userFilters.length', 0),
  isSuspended: Ember.computed.notEmpty('user.suspend_reason'),
  showBadges: setting('enable_badges'),
  showMoreBadges: Ember.computed.gt('moreBadgesCount', 0),
  showDelete: Ember.computed.and("viewingAdmin", "showName", "user.canBeDeleted"),
  linkWebsite: Ember.computed.not('user.isBasic'),
  hasLocationOrWebsite: Ember.computed.or('user.location', 'user.website_name'),

  visible: false,
  user: null,
  username: null,
  avatar: null,
  userLoading: null,
  cardTarget: null,
  post: null,

  // If inside a topic
  topicPostCount: null,

  @computed('user.name')
  nameFirst(name) {
    return !this.siteSettings.prioritize_username_in_ux && name && name.trim().length > 0;
  },

  @computed('user.user_fields.@each.value')
  publicUserFields() {
    const siteUserFields = this.site.get('user_fields');
    if (!Ember.isEmpty(siteUserFields)) {
      const userFields = this.get('user.user_fields');
      return siteUserFields.filterBy('show_on_user_card', true).sortBy('position').map(field => {
        Ember.set(field, 'dasherized_name', field.get('name').dasherize());
        const value = userFields ? userFields[field.get('id')] : null;
        return Ember.isEmpty(value) ? null : Ember.Object.create({ value, field });
      }).compact();
    }
  },

  @computed("user.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  },

  @computed('user.badge_count', 'user.featured_user_badges.length')
  moreBadgesCount: (badgeCount, badgeLength) => badgeCount - badgeLength,

  @computed('user.card_badge.image')
  hasCardBadgeImage: image => image && image.indexOf('fa-') !== 0,

  @observes('user.card_background')
  addBackground() {
    if (!this.get('allowBackgrounds')) { return; }

    const $this = this.$();
    if (!$this) { return; }

    const url = this.get('user.card_background');
    const bg = Ember.isEmpty(url) ? '' : `url(${Discourse.getURLWithCDN(url)})`;
    $this.css('background-image', bg);
  },

  _show(username, $target) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return false;
    }

    // XSS protection (should be encapsulated)
    username = username.toString().replace(/[^A-Za-z0-9_\.\-]/g, "");

    // Don't show on mobile
    if (this.site.mobileView) {
      DiscourseURL.routeTo(`/users/${username}`);
      return false;
    }

    const currentUsername = this.get('username');
    if (username === currentUsername && this.get('userLoading') === username) {
      return;
    }

    const postId = $target.parents('article').data('post-id');

    const wasVisible = this.get('visible');
    const previousTarget = this.get('cardTarget');
    const target = $target[0];
    if (wasVisible) {
      this._close();
      if (target === previousTarget) { return; }
    }

    const post = this.get('viewingTopic') && postId ? this.get('postStream').findLoadedPost(postId) : null;
    this.setProperties({ username, userLoading: username, cardTarget: target, post });

    const args = { stats: false };
    args.include_post_count_for = this.get('topic.id');
    args.skip_track_visit = true;

    User.findByUsername(username, args).then(user => {
      if (user.topic_post_count) {
        this.set('topicPostCount', user.topic_post_count[args.include_post_count_for]);
      }
      this.setProperties({ user, avatar: user, visible: true });

      this._positionCard($target);
    }).catch(() => this._close()).finally(() => this.set('userLoading', null));

    return false;
  },

  didInsertElement() {
    this._super();
    afterTransition(this.$(), this._hide.bind(this));

    $('html').off(clickOutsideEventName)
      .on(clickOutsideEventName, (e) => {
        if (this.get('visible')) {
          const $target = $(e.target);
          if ($target.closest('[data-user-card]').data('userCard') ||
            $target.closest('a.mention').length > 0 ||
            $target.closest('#user-card').length > 0) {
            return;
          }

          this._close();
        }

        return true;
      });

    $('#main-outlet').on(clickDataExpand, '[data-user-card]', (e) => {
      if (wantsNewWindow(e)) { return; }
      const $target = $(e.currentTarget);
      return this._show($target.data('user-card'), $target);
    });

    $('#main-outlet').on(clickMention, 'a.mention', (e) => {
      if (wantsNewWindow(e)) { return; }
      const $target = $(e.target);
      return this._show($target.text().replace(/^@/, ''), $target);
    });
  },

  _positionCard(target) {
    const rtl = ($('html').css('direction')) === 'rtl';
    if (!target) { return; }
    const width = this.$().width();

    Ember.run.schedule('afterRender', () => {
      if (target) {
        let position = target.offset();
        if (position) {

          if (rtl) { // The site direction is rtl
            position.right = $(window).width() - position.left + 10;
            position.left = 'auto';
            let overage = ($(window).width() - 50) - (position.right + width);
            if (overage < 0) {
              position.right += overage;
              position.top += target.height() + 48;
            }
          } else { // The site direction is ltr
            position.left += target.width() + 10;

            let overage = ($(window).width() - 50) - (position.left + width);
            if (overage < 0) {
              position.left += overage;
              position.top += target.height() + 48;
            }
          }

          position.top -= $('#main-outlet').offset().top;
          this.$().css(position);
        }

        // After the card is shown, focus on the first link
        //
        // note: we DO NOT use afterRender here cause _positionCard may
        // run afterwards, if we allowed this to happen the usercard
        // may be offscreen and we may scroll all the way to it on focus
        Ember.run.next(null, () => this.$('a:first').focus() );
      }
    });
  },

  _hide() {
    if (!this.get('visible')) {
      this.$().css({left: -9999, top: -9999});
    }
  },

  _close() {
    this.setProperties({
      visible: false,
      user: null,
      username: null,
      avatar: null,
      userLoading: null,
      cardTarget: null,
      post: null,
      topicPostCount: null
    });
  },

  cleanUp() {
    this._close();
  },

  keyUp(e) {
    if (e.keyCode === 27) { // ESC
      const target = this.get('cardTarget');
      this._close();
      target.focus();
    }
  },

  willDestroyElement() {
    this._super();
    $('html').off(clickOutsideEventName);
    $('#main').off(clickDataExpand).off(clickMention);
  },

  actions: {
    cancelFilter() {
      const postStream = this.get('postStream');
      postStream.cancelFilter();
      postStream.refresh();
      this._close();
    },

    composePrivateMessage(...args) {
      this.sendAction('composePrivateMessage', ...args);
    },

    togglePosts() {
      this.sendAction('togglePosts', this.get('user'));
      this._close();
    },

    deleteUser() {
      this.sendAction('deleteUser', this.get('user'));
    },

    showUser() {
      this.sendAction('showUser', this.get('user'));
      this._close();
    }
  }
});
