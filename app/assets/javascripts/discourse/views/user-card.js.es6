import CleansUp from 'discourse/mixins/cleans-up';

var clickOutsideEventName = "mousedown.outside-user-card",
    clickDataExpand = "click.discourse-user-card",
    clickMention = "click.discourse-user-mention";

export default Discourse.View.extend(CleansUp, {
  elementId: 'user-card',
  classNameBindings: ['controller.visible::hidden', 'controller.showBadges'],
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
    this.appEvents.on('poster:expand', this, '_posterExpand');

    $('html').off(clickOutsideEventName).on(clickOutsideEventName, function(e) {
      if (self.get('controller.visible')) {
        var $target = $(e.target);
        if ($target.closest('.trigger-user-card').length > 0) { return; }
        if (self.$().has(e.target).length !== 0) { return; }

        self.get('controller').close();
      }

      return true;
    });

    $('#main-outlet').on(clickDataExpand, '[data-user-card]', function(e) {
      var $target = $(e.currentTarget);
      self._posterExpand($target);
      self.get('controller').show($target.data('user-card'));
      return false;
    });

    $('#main-outlet').on(clickMention, 'a.mention', function(e) {
      var $target = $(e.target);
      self._posterExpand($target);
      var username = $target.text().replace(/^@/, '');
      self.get('controller').show(username);
      return false;
    });
  }.on('didInsertElement'),

  _posterExpand: function(target) {
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
            position.left += overage;
            position.top += target.height() + 5;
          }
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

    this.appEvents.off('poster:expand', this, '_posterExpand');
  }.on('willDestroyElement')

});
