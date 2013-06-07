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
  topicBinding: 'Discourse.router.topicController.content',

  showDropdown: function($target) {
    var elementId = $target.data('dropdown') || $target.data('notifications'),
        $dropdown = $("#" + elementId),
        $li = $target.closest('li'),
        $ul = $target.closest('ul'),
        $html = $('html');

    var hideDropdown = function() {
      $dropdown.fadeOut('fast');
      $li.removeClass('active');
      $html.data('hide-dropdown', null);
      return $html.off('click.d-dropdown');
    };

    // if a dropdown is active and the user clics on it, close it
    if($li.hasClass('active')) { return hideDropdown(); }
    // otherwhise, mark it as active
    $li.addClass('active');
    // hide the other dropdowns
    $('li', $ul).not($li).removeClass('active');
    $('.d-dropdown').not($dropdown).fadeOut('fast');
    // fade it fast
    $dropdown.fadeIn('fast');
    // autofocus any text input field
    $dropdown.find('input[type=text]').focus().select();

    $html.on('click.d-dropdown', function(e) {
      return $(e.target).closest('.d-dropdown').length > 0 ? true : hideDropdown();
    });

    $html.data('hide-dropdown', hideDropdown);

    return false;
  },

  showNotifications: function() {

    var headerView = this;
    Discourse.ajax('/notifications').then(function(result) {
      headerView.set('notifications', result.map(function(n) {
        return Discourse.Notification.create(n);
      }));

      // We've seen all the notifications now
      Discourse.User.current().set('unread_notifications', 0);
      headerView.showDropdown($('#user-notifications'));
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

  /**
    Display the correct logo in the header, showing a custom small icon if it exists.

    @property logoHTML
  **/
  logoHTML: function() {
    var result = "<div class='title'><a href='" + Discourse.getURL("/") + "'>";
    if (this.get('controller.showExtraInfo')) {
      var logo = Discourse.SiteSettings.logo_small_url;
      if (logo && logo.length > 1) {
        result += "<img class='logo-small' src='" + logo + "' width='33' height='33'>";
      } else {
        result += "<i class='icon-home'></i>";
      }
    } else {
      result += "<img class='logo-big' src=\"" + Discourse.SiteSettings.logo_url + "\" alt=\"" + Discourse.SiteSettings.title + "\" id='site-logo'>";
    }
    result += "</a></div>";
    return new Handlebars.SafeString(result);
  }.property('controller.showExtraInfo'),

  willDestroyElement: function() {
    $(window).unbind('scroll.discourse-dock');
    $(document).unbind('touchmove.discourse-dock');
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').off('click.notifications');
    this.$('a[data-dropdown]').off('click.dropdown');
  },

  didInsertElement: function() {

    var headerView = this;
    this.$('a[data-dropdown]').on('click.dropdown', function(e) {
      return headerView.showDropdown($(e.currentTarget));
    });
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').on('click.notifications', function(e) {
      return headerView.showNotifications(e);
    });
    $(window).bind('scroll.discourse-dock', function() {
      headerView.examineDockHeader();
    });
    $(document).bind('touchmove.discourse-dock', function() {
      headerView.examineDockHeader();
    });
    this.examineDockHeader();

    // Delegate ESC to the composer
    $('body').on('keydown.header', function(e) {
      // Hide dropdowns
      if (e.which === 27) {
        headerView.$('li').removeClass('active');
        headerView.$('.d-dropdown').fadeOut('fast');
      }
      if (headerView.get('editingTopic')) {
        if (e.which === 13) {
          headerView.finishedEdit();
        }
        if (e.which === 27) {
          return headerView.cancelEdit();
        }
      }
    });
  }
});


