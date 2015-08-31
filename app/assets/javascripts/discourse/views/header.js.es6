export default Ember.View.extend({
  tagName: 'header',
  classNames: ['d-header', 'clearfix'],
  classNameBindings: ['editingTopic'],
  templateName: 'header',

  examineDockHeader: function() {
    var headerView = this;

    // Check the dock after the current run loop. While rendering,
    // it's much slower to calculate `outlet.offset()`
    Em.run.next(function () {
      if (!headerView.docAt) {
        var outlet = $('#main-outlet');
        if (!(outlet && outlet.length === 1)) return;
        headerView.docAt = outlet.offset().top;
      }

      var offset = window.pageYOffset || $('html').scrollTop();
      if (offset >= headerView.docAt) {
        if (!headerView.dockedHeader) {
          $('body').addClass('docked');
          headerView.dockedHeader = true;
        }
      } else {
        if (headerView.dockedHeader) {
          $('body').removeClass('docked');
          headerView.dockedHeader = false;
        }
      }
    });
  },

  _tearDown: function() {
    $(window).unbind('scroll.discourse-dock');
    $(document).unbind('touchmove.discourse-dock');
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').off('click.notifications');
    $('body').off('keydown.header');
  }.on('willDestroyElement'),

  _setup: function() {
    const self = this;

    $(window).bind('scroll.discourse-dock', function() {
      self.examineDockHeader();
    });
    $(document).bind('touchmove.discourse-dock', function() {
      self.examineDockHeader();
    });
    self.examineDockHeader();
  }.on('didInsertElement')
});
