(function() {

  window.Discourse.HeaderView = Ember.View.extend({
    tagName: 'header',
    classNames: ['d-header', 'clearfix'],
    classNameBindings: ['editingTopic'],
    templateName: 'header',
    siteBinding: 'Discourse.site',
    currentUserBinding: 'Discourse.currentUser',
    categoriesBinding: 'site.categories',
    topicBinding: 'Discourse.router.topicController.content',
    showDropdown: function($target) {
      var $dropdown, $html, $li, $ul, elementId, hideDropdown,
        _this = this;
      elementId = $target.data('dropdown') || $target.data('notifications');
      $dropdown = jQuery("#" + elementId);
      $li = $target.closest('li');
      $ul = $target.closest('ul');
      $li.addClass('active');
      jQuery('li', $ul).not($li).removeClass('active');
      jQuery('.d-dropdown').not($dropdown).fadeOut('fast');
      $dropdown.fadeIn('fast');
      $dropdown.find('input[type=text]').focus().select();
      $html = jQuery('html');
      hideDropdown = function() {
        $dropdown.fadeOut('fast');
        $li.removeClass('active');
        $html.data('hide-dropdown', null);
        return $html.off('click.d-dropdown touchstart.d-dropdown');
      };
      $html.on('click.d-dropdown touchstart.d-dropdown', function(e) {
        if (jQuery(e.target).closest('.d-dropdown').length > 0) {
          return true;
        }
        return hideDropdown();
      });
      $html.data('hide-dropdown', hideDropdown);
      return false;
    },
    showNotifications: function() {
      var _this = this;
      jQuery.get("/notifications").then(function(result) {
        _this.set('notifications', result.map(function(n) {
          return Discourse.Notification.create(n);
        }));
        /* We've seen all the notifications now
        */

        _this.set('currentUser.unread_notifications', 0);
        _this.set('currentUser.unread_private_messages', 0);
        return _this.showDropdown(jQuery('#user-notifications'));
      });
      return false;
    },
    examineDockHeader: function() {
      var $body, offset, outlet;
      if (!this.docAt) {
        outlet = jQuery('#main-outlet');
        if (!(outlet && outlet.length === 1)) {
          return;
        }
        this.docAt = outlet.offset().top;
      }
      offset = window.pageYOffset || jQuery('html').scrollTop();
      if (offset >= this.docAt) {
        if (!this.dockedHeader) {
          $body = jQuery('body');
          $body.addClass('docked');
          this.dockedHeader = true;
        }
      } else {
        if (this.dockedHeader) {
          jQuery('body').removeClass('docked');
          this.dockedHeader = false;
        }
      }
    },
    willDestroyElement: function() {
      jQuery(window).unbind('scroll.discourse-dock');
      return jQuery(document).unbind('touchmove.discourse-dock');
    },
    didInsertElement: function() {
      var _this = this;
      this.$('a[data-dropdown]').on('click touchstart', function(e) {
        return _this.showDropdown(jQuery(e.currentTarget));
      });
      this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').on('click touchstart', function(e) {
        return _this.showNotifications(e);
      });
      jQuery(window).bind('scroll.discourse-dock', function() {
        return _this.examineDockHeader();
      });
      jQuery(document).bind('touchmove.discourse-dock', function() {
        return _this.examineDockHeader();
      });
      this.examineDockHeader();
      /* Delegate ESC to the composer
      */

      return jQuery('body').on('keydown.header', function(e) {
        /* Hide dropdowns
        */
        if (e.which === 27) {
          _this.$('li').removeClass('active');
          _this.$('.d-dropdown').fadeOut('fast');
        }
        if (_this.get('editingTopic')) {
          if (e.which === 13) {
            _this.finishedEdit();
          }
          if (e.which === 27) {
            return _this.cancelEdit();
          }
        }
      });
    }
  });

}).call(this);
