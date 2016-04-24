import LoadMore from "discourse/mixins/load-more";
import DiscourseURL from 'discourse/lib/url';

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

      if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) {
        return true;
      }

      e.preventDefault();

      var $link = $(e.currentTarget);
      var href = $link.attr('href') || $link.data('href');

      // Remove the href, put it as a data attribute
      if (!$link.data('href')) {
        $link.addClass('no-href');
        $link.data('href', $link.attr('href'));
        $link.attr('href', null);
        // Don't route to this URL
        $link.data('auto-route', true);
      }

      // restore href
      setTimeout(() => {
        $link.removeClass('no-href');
        $link.attr('href', $link.data('href'));
        $link.data('href', null);
      }, 50);

      // warn the user if they can't download the file
      if (Discourse.SiteSettings.prevent_anons_from_downloading_files && $link.hasClass("attachment") && !Discourse.User.current()) {
        bootbox.alert(I18n.t("post.errors.attachment_download_requires_login"));
        return false;
      }

      // If we're on the same site, use the router and track via AJAX
      if (DiscourseURL.isInternal(href) && !$link.hasClass('attachment')) {
        DiscourseURL.routeTo(href);
        return false;
      }

      // Otherwise, use a custom URL with a redirect
      if (Discourse.User.currentProp('external_links_in_new_tab')) {
        var win = window.open(href, '_blank');
        win.focus();
      } else {
        DiscourseURL.redirectTo(href);
      }

      return false;
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
