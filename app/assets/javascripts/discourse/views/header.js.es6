import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.View.extend({
  tagName: 'header',
  classNames: ['d-header', 'clearfix'],
  classNameBindings: ['editingTopic'],
  templateName: 'header',

  examineDockHeader() {
    // Check the dock after the current run loop. While rendering,
    // it's much slower to calculate `outlet.offset()`
    Ember.run.next(() => {
      if (this.docAt === undefined) {
        const outlet = $('#main-outlet');
        if (!(outlet && outlet.length === 1)) return;
        this.docAt = outlet.offset().top;
      }

      const offset = window.pageYOffset || $('html').scrollTop();
      if (offset >= this.docAt) {
        if (!this.dockedHeader) {
          $('body').addClass('docked');
          this.dockedHeader = true;
        }
      } else {
        if (this.dockedHeader) {
          $('body').removeClass('docked');
          this.dockedHeader = false;
        }
      }
    });
  },

  @on('willDestroyElement')
  _tearDown() {
    $(window).unbind('scroll.discourse-dock');
    $(document).unbind('touchmove.discourse-dock');
    this.$('a.unread-private-messages, a.unread-notifications, a[data-notifications]').off('click.notifications');
    $('body').off('keydown.header');
  },

  @on('didInsertElement')
  _setup() {
    $(window).bind('scroll.discourse-dock', () => this.examineDockHeader());
    $(document).bind('touchmove.discourse-dock', () => this.examineDockHeader());
    this.examineDockHeader();
  }
});

export function headerHeight() {
  const $header = $('header.d-header');
  const headerOffset = $header.offset();
  const headerOffsetTop = (headerOffset) ? headerOffset.top : 0;
  return parseInt($header.outerHeight() + headerOffsetTop - $(window).scrollTop());
}
