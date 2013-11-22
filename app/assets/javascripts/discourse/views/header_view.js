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

    // we need to ensure we are rendered,
    //  this optimises the speed of the initial render
    var render = $target.data('render');
    if(render){
      if(!this.get(render)){
        this.set(render, true);
        Em.run.next(this, function(){
          this.showDropdown($target);
        });
        return;
      }
    }

    var hideDropdown = function() {
      $dropdown.fadeOut('fast');
      $li.removeClass('active');
      $html.data('hide-dropdown', null);
      return $html.off('click.d-dropdown');
    };

    // if a dropdown is active and the user clicks on it, close it
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

  showDropdownBySelector: function(selector) {
    this.showDropdown($(selector));
  },

  showNotifications: function() {
    this.get("controller").send("showNotifications", this);
  },

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

  willDestroyElement: function() {
    $(window).unbind('scroll.discourse-dock');
    $(document).unbind('touchmove.discourse-dock');
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').off('click.notifications');
    this.$('a[data-dropdown]').off('click.dropdown');
  },

  didInsertElement: function() {

    var headerView = this;
    this.$('a[data-dropdown]').on('click.dropdown', function(e) {
      headerView.showDropdown($(e.currentTarget));
      return false;
    });
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').on('click.notifications', function(e) {
      headerView.showNotifications(e);
      return false;
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


