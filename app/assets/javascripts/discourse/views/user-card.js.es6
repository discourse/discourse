import CleansUp from 'discourse/mixins/cleans-up';

var clickOutsideEventName = "mousedown.outside-user-card",
    clickDataExpand = "click.discourse-user-card",
    clickMention = "click.discourse-user-mention";

export default Discourse.View.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['controller.visible::hidden', 'controller.showBadges', 'controller.hasCardBadgeImage'],
  allowBackgrounds: Discourse.computed.setting('allow_profile_backgrounds'),

  addBackground: function() {
    var url = this.get('controller.user.card_background');
    if (!this.get('allowBackgrounds')) { return; }

    var $this = this.$();
    if (!$this) { return; }

    if (Ember.empty(url)) {
      $this.css('background-image', '').addClass('no-bg');
    } else {
      $this.css('background-image', "url(" + url + ")").removeClass('no-bg');
    }
  }.observes('controller.user.card_background'),

  _setup: function() {
    var self = this;

    $('html').off(clickOutsideEventName).on(clickOutsideEventName, function(e) {
      if (self.get('controller.visible')) {
        var $target = $(e.target);
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
      self._willShow($target);
      self.get('controller').show(username, $target[0]);
      return false;
    };

    $('#main-outlet').on(clickDataExpand, '[data-user-card]', function(e) {
      var $target = $(e.currentTarget);
      var username = $target.data('user-card');
      return expand(username, $target);
    });

    $('#main-outlet').on(clickMention, 'a.mention', function(e) {
      var $target = $(e.target);
      var username = $target.text().replace(/^@/, '');
      return expand(username, $target);
    });

    this.appEvents.on('usercard:shown', this, '_shown');
  }.on('didInsertElement'),

  _shown: function() {
    var self = this;
    // After the card is shown, focus on the first link
    Ember.run.scheduleOnce('afterRender', function() {
      self.$('a:first').focus();
    });
  },

  _willShow: function(target) {
    if (!target) { return; }
    var self = this,
        width = this.$().width();
    Em.run.schedule('afterRender', function() {
      if (target) {
        var position = target.offset();
        if (position) {
          position.left += target.width() + 10;

          var overage = ($(window).width() - 50) - (position.left + width);
          if (overage < 0) {
            position.left -= (width/2) - 10;
            position.top += target.height() + 8;
          }

          position.top -= $('#main-outlet').offset().top;
          self.$().css(position);
        }
      }
    });
  },

  cleanUp: function() {
    this.get('controller').close();
  },

  _removeEvents: function() {
    $('html').off(clickOutsideEventName);
    $('#main').off(clickDataExpand);
    $('#main').off(clickMention);

    this.appEvents.off('usercard:shown', this, '_shown');
  }.on('willDestroyElement')

});
