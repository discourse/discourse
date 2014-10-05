import CleansUp from 'discourse/mixins/cleans-up';

var clickOutsideEventName = "mousedown.outside-user-expansion",
    clickDataExpand = "click.discourse-user-expand",
    clickMention = "click.discourse-user-mention";

export default Discourse.View.extend(CleansUp, {
  elementId: 'user-expansion',
  classNameBindings: ['controller.visible::hidden', 'controller.showBadges'],

  _setup: function() {
    var self = this;
    this.appEvents.on('poster:expand', this, '_posterExpand');

    $('html').off(clickOutsideEventName).on(clickOutsideEventName, function(e) {
      if (self.get('controller.visible')) {
        var $target = $(e.target);
        if ($target.closest('.trigger-expansion').length > 0) { return; }
        if (self.$().has(e.target).length !== 0) { return; }

        self.get('controller').close();
      }

      return true;
    });

    $('#main-outlet').on(clickDataExpand, '[data-user-expand]', function(e) {
      var $target = $(e.currentTarget);
      self._posterExpand($target);
      self.get('controller').show($target.data('user-expand'));
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
