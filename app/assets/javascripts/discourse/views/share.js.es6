import { wantsNewWindow } from 'discourse/lib/intercept-click';

export default Ember.View.extend({
  templateName: 'share',
  elementId: 'share-link',
  classNameBindings: ['hasLink'],

  hasLink: function() {
    if (!Ember.isEmpty(this.get('controller.link'))) return 'visible';
    return null;
  }.property('controller.link'),

  linkChanged: function() {
    const self = this;
    if (!Ember.isEmpty(this.get('controller.link'))) {
      Em.run.next(function() {
        if (!self.capabilities.touch) {
          var $linkInput = $('#share-link input');
          $linkInput.val(self.get('controller.link'));

          // Wait for the fade-in transition to finish before selecting the link:
          window.setTimeout(function() {
            $linkInput.select().focus();
          }, 160);
        } else {
          var $linkForTouch = $('#share-link .share-for-touch a');
          $linkForTouch.attr('href',self.get('controller.link'));
          $linkForTouch.html(self.get('controller.link'));
          var range = window.document.createRange();
          range.selectNode($linkForTouch[0]);
          window.getSelection().addRange(range);
        }
      });
    }
  }.observes('controller.link'),

  didInsertElement: function() {
    var self = this,
        $html = $('html');

    $html.on('mousedown.outside-share-link', function(e) {
      // Use mousedown instead of click so this event is handled before routing occurs when a
      // link is clicked (which is a click event) while the share dialog is showing.
      if (self.$().has(e.target).length !== 0) { return; }

      self.get('controller').send('close');
      return true;
    });

    function showPanel($target, url, postNumber, date) {
      const $currentTargetOffset = $target.offset();
      const $shareLink = $('#share-link');

      // Relative urls
      if (url.indexOf("/") === 0) {
        url = window.location.protocol + "//" + window.location.host + url;
      }

      const shareLinkWidth = $shareLink.width();
      let x = $currentTargetOffset.left - (shareLinkWidth / 2);
      if (x < 25) {
        x = 25;
      }
      if (x + shareLinkWidth > $(window).width()) {
        x -= shareLinkWidth / 2;
      }

      const header = $('.d-header');
      let y = $currentTargetOffset.top - ($shareLink.height() + 20);
      if (y < header.offset().top + header.height()) {
        y = $currentTargetOffset.top + 10;
      }

      $shareLink.css({top: "" + y + "px"});

      if (!self.site.mobileView) {
        $shareLink.css({left: "" + x + "px"});
      }

      self.set('controller.link', url);
      self.set('controller.postNumber', postNumber);
      self.set('controller.date', date);
    }

    this.appEvents.on('share:url', (url, $target) => showPanel($target, url));

    $html.on('click.discoure-share-link', '[data-share-url]', function(e) {
      // if they want to open in a new tab, let it so
      if (wantsNewWindow(e)) { return true; }

      e.preventDefault();

      const $currentTarget = $(e.currentTarget),
            url = $currentTarget.data('share-url'),
            postNumber = $currentTarget.data('post-number'),
            date = $currentTarget.children().data('time');
      showPanel($currentTarget, url, postNumber, date);
      return false;
    });

    $html.on('keydown.share-view', function(e){
      if (e.keyCode === 27) {
        self.get('controller').send('close');
      }
    });
  },

  willDestroyElement: function() {
    this.get('controller').send('close');

    $('html').off('click.discoure-share-link')
             .off('mousedown.outside-share-link')
             .off('keydown.share-view');
  }

});
