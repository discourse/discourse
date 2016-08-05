import computed from 'ember-addons/ember-computed-decorators';
import { observes } from 'ember-addons/ember-computed-decorators';
import { wantsNewWindow } from 'discourse/lib/intercept-click';

export default Ember.View.extend({
  templateName: 'share',
  elementId: 'share-link',
  classNameBindings: ['hasLink'],

  @computed('controller.link')
  hasLink(link) {
    return !Ember.isEmpty(link) ? 'visible' : null;
  },

  @observes('controller.link')
  linkChanged() {
    const link = this.get('controller.link');
    if (!Ember.isEmpty(link)) {
      Ember.run.next(() => {
        if (!this.capabilities.touch) {
          const $linkInput = $('#share-link input');
          $linkInput.val(link);

          // Wait for the fade-in transition to finish before selecting the link:
          window.setTimeout(() => $linkInput.select().focus(), 160);
        } else {
          const $linkForTouch = $('#share-link .share-for-touch a');
          $linkForTouch.attr('href', link);
          $linkForTouch.html(link);
          const range = window.document.createRange();
          range.selectNode($linkForTouch[0]);
          window.getSelection().addRange(range);
        }
      });
    }
  },

  didInsertElement() {
    const self = this;
    const $html = $('html');

    $html.on('mousedown.outside-share-link', e => {
      // Use mousedown instead of click so this event is handled before routing occurs when a
      // link is clicked (which is a click event) while the share dialog is showing.
      if (this.$().has(e.target).length !== 0) { return; }
      this.get('controller').send('close');
      return true;
    });

    function showPanel($target, url, postNumber, date, postId) {
      const $currentTargetOffset = $target.offset();
      const $shareLink = $('#share-link');

      // Relative urls
      if (url.indexOf("/") === 0) {
        url = window.location.protocol + "//" + window.location.host + url;
      }

      const shareLinkWidth = $shareLink.width();
      let x = $currentTargetOffset.left - (shareLinkWidth / 2);
      if (x < 25) { x = 25; }
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
      self.set('controller.postId', postId);
      self.set('controller.date', date);
    }

    this.appEvents.on('share:url', (url, $target) => showPanel($target, url));

    $html.on('click.discoure-share-link', '[data-share-url]', e => {
      // if they want to open in a new tab, let it so
      if (wantsNewWindow(e)) { return true; }

      e.preventDefault();

      const $currentTarget = $(e.currentTarget),
            url = $currentTarget.data('share-url'),
            postNumber = $currentTarget.data('post-number'),
            postId = $currentTarget.closest('article').data('post-id'),
            date = $currentTarget.children().data('time');
      showPanel($currentTarget, url, postNumber, date, postId);
      return false;
    });

    $html.on('keydown.share-view', e => {
      if (e.keyCode === 27) {
        this.get('controller').send('close');
      }
    });
  },

  willDestroyElement() {
    this.get('controller').send('close');

    $('html').off('click.discoure-share-link')
             .off('mousedown.outside-share-link')
             .off('keydown.share-view');
  }

});
