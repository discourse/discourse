(function() {

  window.Discourse.ShareView = Discourse.View.extend({
    templateName: 'share',
    elementId: 'share-link',
    classNameBindings: ['hasLink'],
    title: (function() {
      if (this.get('controller.type') === 'topic') {
        return Em.String.i18n('share.topic');
      } else {
        return Em.String.i18n('share.post');
      }
    }).property('controller.type'),
    hasLink: (function() {
      if (this.present('controller.link')) {
        return 'visible';
      }
      return null;
    }).property('controller.link'),
    linkChanged: (function() {
      if (this.present('controller.link')) {
        return jQuery('#share-link input').val(this.get('controller.link')).select().focus();
      }
    }).observes('controller.link'),
    didInsertElement: function() {
      var _this = this;
      jQuery('html').on('click.outside-share-link', function(e) {
        if (_this.$().has(e.target).length !== 0) {
          return;
        }
        _this.get('controller').close();
        return true;
      });
      jQuery('html').on('touchstart.outside-share-link', function(e) {
        if (_this.$().has(e.target).length !== 0) {
          return;
        }
        _this.get('controller').close();
        return true;
      });
      return jQuery('html').on('click.discoure-share-link', '[data-share-url]', function(e) {
        var $currentTarget, url;
        e.preventDefault();
        $currentTarget = jQuery(e.currentTarget);
        url = $currentTarget.data('share-url');
        /* Relative urls
        */

        if (url.indexOf("/") === 0) {
          url = window.location.protocol + "//" + window.location.host + url;
        }
        _this.get('controller').shareLink(e, url);
        return false;
      });
    },
    willDestroyElement: function() {
      jQuery('html').off('click.discoure-share-link');
      jQuery('html').off('click.outside-share-link');
      return jQuery('html').off('touchstart.outside-share-link');
    }
  });

}).call(this);
