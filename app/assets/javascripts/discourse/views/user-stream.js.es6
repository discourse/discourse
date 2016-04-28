import LoadMore from "discourse/mixins/load-more";
import ClickTrack from 'discourse/lib/click-track';

export default Ember.View.extend(LoadMore, {
  loading: false,
  eyelineSelector: '.user-stream .item',
  classNames: ['user-stream'],

  _scrollTopOnModelChange: function() {
    Em.run.schedule('afterRender', function() {
      $(document).scrollTop(0);
    });
  }.observes('controller.model.user.id'),

  _inserted: function() {
    this.bindScrolling({name: 'user-stream-view'});

    $(window).on('resize.discourse-on-scroll', () => this.scrolled());

    this.$().on('mouseup.discourse-redirect', '.excerpt a', function(e) {
      // bypass if we are selecting stuff
      const selection = window.getSelection && window.getSelection();
      if (selection.type === "Range" || selection.rangeCount > 0) {
        if (Discourse.Utilities.selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }

      return ClickTrack.trackClick(e, ClickTrack.OTHER);
    });

  }.on('didInsertElement'),

  // This view is being removed. Shut down operations
  _destroyed: function() {
    this.unbindScrolling('user-stream-view');
    $(window).unbind('resize.discourse-on-scroll');

    // Unbind link tracking
    this.$().off('mouseup.discourse-redirect', '.excerpt a');

  }.on('willDestroyElement'),

  actions: {
    loadMore() {
      const self = this;
      if (this.get('loading')) { return; }

      this.set('loading', true);
      const stream = this.get('controller.model');
      stream.findItems().then(function() {
        self.set('loading', false);
        self.get('eyeline').flushRest();
      });
    }
  }
});
