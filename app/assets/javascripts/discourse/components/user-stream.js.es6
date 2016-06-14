import LoadMore from "discourse/mixins/load-more";
import ClickTrack from 'discourse/lib/click-track';
import { selectedText } from 'discourse/lib/utilities';

export default Ember.Component.extend(LoadMore, {
  loading: false,
  eyelineSelector: '.user-stream .item',
  classNames: ['user-stream'],

  _scrollTopOnModelChange: function() {
    Em.run.schedule('afterRender', () => $(document).scrollTop(0));
  }.observes('stream.user.id'),

  _inserted: function() {
    this.bindScrolling({name: 'user-stream-view'});

    $(window).on('resize.discourse-on-scroll', () => this.scrolled());

    this.$().on('mouseup.discourse-redirect', '.excerpt a', function(e) {
      // bypass if we are selecting stuff
      const selection = window.getSelection && window.getSelection();
      if (selection.type === "Range" || selection.rangeCount > 0) {
        if (selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }

      return ClickTrack.trackClick(e);
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
      if (this.get('loading')) { return; }

      this.set('loading', true);
      const stream = this.get('stream');
      stream.findItems().then(() => {
        this.set('loading', false);
        this.get('eyeline').flushRest();
      });
    }
  }
});
