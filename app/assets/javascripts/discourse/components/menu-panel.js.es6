import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':menu-panel', 'visible::hidden', 'viewMode'],
  attributeBindings: ['style'],

  showClose: Ember.computed.equal('viewMode', 'slide-in'),

  @computed('viewMode', 'visible')
  style(viewMode) {
    if (viewMode === 'drop-down') {
      const $buttonPanel = $('header ul.icons');
      if ($buttonPanel.length === 0) { return; }

      const buttonPanelPos = $buttonPanel.offset();
      const myWidth = this.$().width();

      const posTop = parseInt(buttonPanelPos.top + $buttonPanel.height() - $('header.d-header').offset().top);
      const posLeft = parseInt(buttonPanelPos.left + $buttonPanel.width() - myWidth);

      return `left: ${posLeft}px; top: ${posTop}px`.htmlSafe();
    } else {
      const headerHeight = parseInt($('header.d-header').height() + 3);
      return `top: ${headerHeight}px`.htmlSafe();
    }
  },

  @computed('viewMode', 'visible')
  bodyStyle(viewMode) {
    if (viewMode === 'drop-down') {
      const height = parseInt($(window).height() * 0.8)
      return `height: ${height}px`.htmlSafe();
    }
  },

  @computed('force')
  viewMode() {
    const force = this.get('force');
    if (force) { return force; }

    return ($(window).width() < 1024) ? 'slide-in' : 'drop-down';
  },

  @observes('viewMode', 'visible')
  _visibleChanged() {
    const isDropdown = (this.get('viewMode') === 'drop-down');
    const markActive = this.get('markActive');

    if (this.get('visible')) {

      if (isDropdown && markActive) {
        $(markActive).addClass('active');
      }

      $('html').on('click.close-menu-panel', (e) => {
        const $target = $(e.target);
        if ($target.closest(markActive).length > 0) { return; }
        if ($target.closest('.menu-panel').length > 0) { return; }
        this.hide();
      });

    } else {
      if (markActive) {
        $(markActive).removeClass('active');
      }
      $('html').off('click.close-menu-panel');
    }
  },

  @computed()
  showKeyboardShortcuts() {
    return !Discourse.Mobile.mobileView && !this.capabilities.touch;
  },

  @computed()
  showMobileToggle() {
    return Discourse.Mobile.mobileView || (this.siteSettings.enable_mobile_theme && this.capabilities.touch);
  },

  @computed()
  mobileViewLinkTextKey() {
    return Discourse.Mobile.mobileView ? "desktop_view" : "mobile_view";
  },

  @computed()
  faqUrl() {
    return this.siteSettings.faq_url ? this.siteSettings.faq_url : Discourse.getURL('/faq');
  },

  @on('didInsertElement')
  _bindEvents() {
    this.$().on('click.discourse-menu-panel', 'a', () => {
      this.hide();
    });

    this.appEvents.on('dropdowns:closeAll', this, this.hide);

    $('body').on('keydown.discourse-menu-panel', (e) => {
      if (e.which === 27) {
        this.hide();
      }
    });

    // Recompute styles on resize
    $(window).on('resize.discourse-menu-panel', () => {
      this.propertyDidChange('viewMode');
    });
  },

  @on('willDestroyElement')
  _removeEvents() {
    this.appEvents.off('dropdowns:closeAll', this, this.hide);
    this.$().off('click.discourse-menu-panel');
    $('body').off('keydown.discourse-menu-panel');
    $('html').off('click.close-menu-panel');
    $(window).off('resize.discourse-menu-panel');
  },

  hide() {
    this.set('visible', false);
  },

  actions: {
    close() {
      this.hide();
    }
  }
});
