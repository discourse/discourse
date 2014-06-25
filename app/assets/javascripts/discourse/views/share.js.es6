/**
  This view is used for rendering the "share" interface for a post

  @class ShareView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend({
  templateName: 'share',
  elementId: 'share-link',
  classNameBindings: ['hasLink'],

  title: function() {
    if (this.get('controller.type') === 'topic') return I18n.t('share.topic');
    var postNumber = this.get('controller.postNumber');
    if (postNumber) {
      return I18n.t('share.post', {postNumber: this.get('controller.postNumber')});
    } else {
      return I18n.t('share.topic');
    }
  }.property('controller.type', 'controller.postNumber'),

  hasLink: function() {
    if (this.present('controller.link')) return 'visible';
    return null;
  }.property('controller.link'),

  linkChanged: function() {
    if (this.present('controller.link')) {
      var $linkInput = $('#share-link input');
      $linkInput.val(this.get('controller.link'));

      // Wait for the fade-in transition to finish before selecting the link:
      window.setTimeout(function() {
        $linkInput.select().focus();
      }, 160);
    }
  }.observes('controller.link'),

  didInsertElement: function() {
    var shareView = this,
        $html = $('html');

    $html.on('mousedown.outside-share-link', function(e) {
      // Use mousedown instead of click so this event is handled before routing occurs when a
      // link is clicked (which is a click event) while the share dialog is showing.
      if (shareView.$().has(e.target).length !== 0) { return; }

      shareView.get('controller').send('close');
      return true;
    });

    $html.on('click.discoure-share-link', '[data-share-url]', function(e) {
      // if they want to open in a new tab, let it so
      if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) { return true; }

      e.preventDefault();

      var $currentTarget = $(e.currentTarget),
          $currentTargetOffset = $currentTarget.offset(),
          $shareLink = $('#share-link'),
          url = $currentTarget.data('share-url'),
          postNumber = $currentTarget.data('post-number'),
          date = $currentTarget.children().data('time');

      // Relative urls
      if (url.indexOf("/") === 0) {
        url = window.location.protocol + "//" + window.location.host + url;
      }

      var shareLinkWidth = $shareLink.width();
      var x = $currentTargetOffset.left - (shareLinkWidth / 2);
      if (x < 25) {
        x = 25;
      }
      if (x + shareLinkWidth > $(window).width()) {
        x -= shareLinkWidth / 2;
      }

      var header = $('.d-header');
      var y = $currentTargetOffset.top - ($shareLink.height() + 20);
      if (y < header.offset().top + header.height()) {
        y = $currentTargetOffset.top + 10;
      }

      $shareLink.css({
        left: "" + x + "px",
        top: "" + y + "px"
      });

      shareView.set('controller.link', url);
      shareView.set('controller.postNumber', postNumber);
      shareView.set('controller.date', date);

      return false;
    });

    $html.on('keydown.share-view', function(e){
      if (e.keyCode === 27) {
        shareView.get('controller').send('close');
      }
    });
  },

  willDestroyElement: function() {
    $('html').off('click.discoure-share-link')
             .off('mousedown.outside-share-link')
             .off('keydown.share-view');
  }

});
