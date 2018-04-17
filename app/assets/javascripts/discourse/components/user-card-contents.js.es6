import { wantsNewWindow } from 'discourse/lib/intercept-click';
import CleansUp from 'discourse/mixins/cleans-up';
import afterTransition from 'discourse/lib/after-transition';
import { setting } from 'discourse/lib/computed';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import DiscourseURL from 'discourse/lib/url';
import User from 'discourse/models/user';
import { userPath } from 'discourse/lib/url';

const clickOutsideEventName = "mousedown.outside-user-card";
const clickDataExpand = "click.discourse-user-card";
const clickMention = "click.discourse-user-mention";
const groupClickMention = "click.discourse-group-mention";
const groupClickDataExpand = "click.discourse-group-card";

const maxMembersToDisplay = 10;

export default Ember.Component.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['visible:show', 'showBadges', 'hasCardBadgeImage', 'user.card_background::no-bg'],
  allowBackgrounds: setting('allow_profile_backgrounds'),
  showBadges: setting('enable_badges'),

  postStream: Ember.computed.alias('topic.postStream'),
  viewingTopic: Ember.computed.match('currentPath', /^topic\./),

  visible: false,
  user: null,
  group: null,
  username: null,
  avatar: null,
  userLoading: null,
  cardTarget: null,
  post: null,
  cardType: null,

  // If inside a topic
  topicPostCount: null,

  @computed('cardType')
  isUserShown(cardType) {
    return cardType === 'user';
  },

  @computed('cardType')
  isGroupShown(cardType) {
    return cardType === 'group';
  },

  @observes('user.card_background')
  addBackground() {
    if (!this.get('allowBackgrounds')) { return; }

    const $this = this.$();
    if (!$this) { return; }

    const url = this.get('user.card_background');
    const bg = Ember.isEmpty(url) ? '' : `url(${Discourse.getURLWithCDN(url)})`;
    $this.css('background-image', bg);
  },

  @computed('user.card_badge.image')
  hasCardBadgeImage: image => image && image.indexOf('fa-') !== 0,

  _showUser(username, $target) {
    const args = { stats: false };
    args.include_post_count_for = this.get('topic.id');

    User.findByUsername(username, args).then(user => {
      if (user.topic_post_count) {
        this.set('topicPostCount', user.topic_post_count[args.include_post_count_for]);
      }
      this.setProperties({ user, avatar: user, visible: true, cardType: 'user' });

      this._positionCard($target);
    }).catch(() => this._close()).finally(() => this.set('userLoading', null));
  },

  _showGroup(groupname, $target) {
    this.store.find("group", groupname).then(group => {
      this.setProperties({ group, avatar: group, visible: true, cardType: 'group' });
      this._positionCard($target);
      if(!group.flair_url && !group.flair_bg_color) {
        group.set('flair_url', 'fa-users');
      }
      group.set('limit', maxMembersToDisplay);
      return group.findMembers();
    }).catch(() => this._close()).finally(() => this.set('userLoading', null));
  },

  _show(username, $target, userCardType) {
    // No user card for anon
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      return false;
    }

    username = Ember.Handlebars.Utils.escapeExpression(username.toString());

    // Don't show on mobile
    if (this.site.mobileView) {
      DiscourseURL.routeTo(userPath(username));
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

    if(userCardType === 'group') {
      this._showGroup(username, $target);
    }
    else if(userCardType === 'user') {
      this._showUser(username, $target);
    }


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
      return this._show($target.data('user-card'), $target, 'user');
    });

    $('#main-outlet').on(clickMention, 'a.mention', (e) => {
      if (wantsNewWindow(e)) { return; }
      const $target = $(e.target);
      return this._show($target.text().replace(/^@/, ''), $target, 'user');
    });

    $('#main-outlet').on(groupClickDataExpand, '[data-group-card]', (e) => {
      if (wantsNewWindow(e)) { return; }
      const $target = $(e.currentTarget);
      return this._show($target.data('group-card'), $target, 'group');
    });

    $('#main-outlet').on(groupClickMention, 'a.mention-group', (e) => {
      if (wantsNewWindow(e)) { return; }
      const $target = $(e.target);
      return this._show($target.text().replace(/^@/, ''), $target, 'group');
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
      group: null,
      username: null,
      avatar: null,
      userLoading: null,
      cardTarget: null,
      post: null,
      topicPostCount: null,
      cardType: null
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
    $('#main').off(clickDataExpand).off(clickMention).off(groupClickMention).off(groupClickDataExpand);
  },

  actions: {
    close() {
      this._close();
    },

    cancelFilter() {
      const postStream = this.get('postStream');
      postStream.cancelFilter();
      postStream.refresh();
      this._close();
    },

    composePrivateMessage(...args) {
      this.sendAction('composePrivateMessage', ...args);
    },

    messageGroup() {
      this.sendAction('createNewMessageViaParams', this.get('group.name'));
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
    },

    showGroup() {
      this.sendAction('showGroup', this.get('group'));
      this._close();
    },

    checkEmail(user) {
      user.checkEmail();
    }
  }
});
