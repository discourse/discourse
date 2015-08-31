import { setting } from 'discourse/lib/computed';
import CleansUp from 'discourse/mixins/cleans-up';
import afterTransition from 'discourse/lib/after-transition';

const clickOutsideEventName = "mousedown.outside-user-card",
  clickDataExpand = "click.discourse-user-card",
  clickMention = "click.discourse-user-mention";

export default Ember.View.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['controller.visible:show', 'controller.showBadges', 'controller.hasCardBadgeImage'],
  allowBackgrounds: setting('allow_profile_backgrounds'),

  addBackground: function() {
    const url = this.get('controller.user.card_background');

    if (!this.get('allowBackgrounds')) { return; }

    const $this = this.$();
    if (!$this) { return; }

    if (Ember.isEmpty(url)) {
      $this.css('background-image', '').addClass('no-bg');
    } else {
      $this.css('background-image', "url(" + Discourse.getURLWithCDN(url) + ")").removeClass('no-bg');
    }
  }.observes('controller.user.card_background'),

  _setup: function() {
    afterTransition(this.$(), this._hide.bind(this));

    $('html').off(clickOutsideEventName)
      .on(clickOutsideEventName, (e) => {
        if (this.get('controller.visible')) {
          const $target = $(e.target);
          if ($target.closest('[data-user-card]').data('userCard') ||
            $target.closest('a.mention').length > 0 ||
            $target.closest('#user-card').length > 0) {
            return;
          }

          this.get('controller').close();
        }

        return true;
      });

    const expand = (username, $target) => {
      const postId = $target.parents('article').data('post-id'),
        user = this.get('controller').show(username, postId, $target[0]);
      if (user !== undefined) {
        user.then( () => this._willShow($target) ).catch( () => this._hide() );
      } else {
        this._hide();
      }
      return false;
    };

    $('#main-outlet').on(clickDataExpand, '[data-user-card]', (e) => {
      if (e.ctrlKey || e.metaKey) { return; }

      const $target = $(e.currentTarget),
        username = $target.data('user-card');
      return expand(username, $target);
    });

    $('#main-outlet').on(clickMention, 'a.mention', (e) => {
      if (e.ctrlKey || e.metaKey) { return; }

      const $target = $(e.target),
        username = $target.text().replace(/^@/, '');
      return expand(username, $target);
    });
    this.appEvents.on('usercard:shown', this, '_shown');
  }.on('didInsertElement'),

  _shown() {
    // After the card is shown, focus on the first link
    //
    // note: we DO NOT use afterRender here cause _willShow may
    //  run after _shown, if we allowed this to happen the usercard
    //  may be offscreen and we may scroll all the way to it on focus
    Ember.run.next(null, () => this.$('a:first').focus() );
  },

  _willShow(target) {
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
        this.appEvents.trigger('usercard:shown');
      }
    });
  },

  _hide() {
    if (!this.get('controller.visible')) {
      this.$().css({left: -9999, top: -9999});
    }
  },

  cleanUp() {
    this.get('controller').close();
  },

  keyUp(e) {
    if (e.keyCode === 27) { // ESC
      const target = this.get('controller.cardTarget');
      this.cleanUp();
      target.focus();
    }
  },

  _removeEvents: function() {
    $('html').off(clickOutsideEventName);

    $('#main').off(clickDataExpand).off(clickMention);

    this.appEvents.off('usercard:shown', this, '_shown');
  }.on('willDestroyElement')

});
