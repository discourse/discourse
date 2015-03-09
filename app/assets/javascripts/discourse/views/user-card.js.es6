import CleansUp from 'discourse/mixins/cleans-up';

import afterTransition from 'discourse/lib/after-transition';

const clickOutsideEventName = "mousedown.outside-user-card",
      clickDataExpand = "click.discourse-user-card",
      clickMention = "click.discourse-user-mention";

export default Discourse.View.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['controller.visible:show', 'controller.showBadges', 'controller.hasCardBadgeImage'],
  allowBackgrounds: Discourse.computed.setting('allow_profile_backgrounds'),

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
    const self = this;

    afterTransition(self.$(), this._hide.bind(this));

    $('html').off(clickOutsideEventName)
             .on(clickOutsideEventName, function(e) {
      if (self.get('controller.visible')) {
        const $target = $(e.target);
        if ($target.closest('[data-user-card]').data('userCard') ||
            $target.closest('a.mention').length > 0 ||
            $target.closest('#user-card').length > 0) {
          return;
        }

        self.get('controller').close();
      }

      return true;
    });

    var expand = function(username, $target){
      const postId = $target.parents('article').data('post-id');
      self.get('controller')
          .show(username, postId, $target[0])
          .then(function() {
            self._willShow($target);
          }).catch(function() {
            self._hide();
          });
      return false;
    };

    $('#main-outlet').on(clickDataExpand, '[data-user-card]', function(e) {
      const $target = $(e.currentTarget),
            username = $target.data('user-card');
      return expand(username, $target);
    });

    $('#main-outlet').on(clickMention, 'a.mention', function(e) {
      const $target = $(e.target),
            username = $target.text().replace(/^@/, '');
      return expand(username, $target);
    });

    this.appEvents.on('usercard:shown', this, '_shown');
  }.on('didInsertElement'),

  _shown() {
    // After the card is shown, focus on the first link
    Ember.run.scheduleOnce('afterRender', () => this.$('a:first').focus() );
  },

  _willShow(target) {
    if (!target) { return; }
    const self = this,
          width = this.$().width();
    Em.run.schedule('afterRender', function() {
      if (target) {
        let position = target.offset();
        if (position) {
          position.left += target.width() + 10;

          const overage = ($(window).width() - 50) - (position.left + width);
          if (overage < 0) {
            position.left += overage;
            position.top += target.height() + 8;
          }

          position.top -= $('#main-outlet').offset().top;
          self.$().css(position);
        }
      }
    });
  },

  _hide() {
    if (!this.get('controller.visible')) {
      this.$().css({ left: -9999, top: -9999 });
    }
  },

  cleanUp() {
    this.get('controller').close();
  },

  _removeEvents: function() {
    $('html').off(clickOutsideEventName);

    $('#main').off(clickDataExpand)
              .off(clickMention);

    this.appEvents.off('usercard:shown', this, '_shown');
  }.on('willDestroyElement')

});
