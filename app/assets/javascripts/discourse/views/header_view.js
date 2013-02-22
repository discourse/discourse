/**
  This view handles rendering of the header of the site

  @class HeaderView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.HeaderView = Discourse.View.extend({
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
    $dropdown = $("#" + elementId);
    $li = $target.closest('li');
    $ul = $target.closest('ul');
    $li.addClass('active');
    $('li', $ul).not($li).removeClass('active');
    $('.d-dropdown').not($dropdown).fadeOut('fast');
    $dropdown.fadeIn('fast');
    $dropdown.find('input[type=text]').focus().select();
    $html = $('html');
    hideDropdown = function() {
      $dropdown.fadeOut('fast');
      $li.removeClass('active');
      $html.data('hide-dropdown', null);
      return $html.off('click.d-dropdown');
    };
    $html.on('click.d-dropdown', function(e) {
      if ($(e.target).closest('.d-dropdown').length > 0) {
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
      // We've seen all the notifications now
      _this.set('currentUser.unread_notifications', 0);
      _this.set('currentUser.unread_private_messages', 0);
      return _this.showDropdown($('#user-notifications'));
    });
    return false;
  },

  examineDockHeader: function() {
    var $body, offset, outlet;
    if (!this.docAt) {
      outlet = $('#main-outlet');
      if (!(outlet && outlet.length === 1)) return;
      this.docAt = outlet.offset().top;
    }
    offset = window.pageYOffset || $('html').scrollTop();
    if (offset >= this.docAt) {
      if (!this.dockedHeader) {
        $body = $('body');
        $body.addClass('docked');
        this.dockedHeader = true;
      }
    } else {
      if (this.dockedHeader) {
        $('body').removeClass('docked');
        this.dockedHeader = false;
      }
    }
  },

  willDestroyElement: function() {
    $(window).unbind('scroll.discourse-dock');
    return $(document).unbind('touchmove.discourse-dock');
  },

  didInsertElement: function() {
    var _this = this;
    this.$('a[data-dropdown]').on('click', function(e) {
      return _this.showDropdown($(e.currentTarget));
    });
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').on('click', function(e) {
      return _this.showNotifications(e);
    });
    $(window).bind('scroll.discourse-dock', function() {
      return _this.examineDockHeader();
    });
    $(document).bind('touchmove.discourse-dock', function() {
      return _this.examineDockHeader();
    });
    this.examineDockHeader();

    // Delegate ESC to the composer
    return $('body').on('keydown.header', function(e) {
      // Hide dropdowns
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


