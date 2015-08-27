import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';

const PANEL_BODY_MARGIN = 30;

export default Ember.Component.extend({
  classNameBindings: [':menu-panel', 'visible::hidden', 'viewMode'],

  showClose: Ember.computed.equal('viewMode', 'slide-in'),

  _resizeComponent() {
    if (!this.get('visible')) { return; }

    const viewMode = this.get('viewMode');
    const $panelBody = this.$('.panel-body');

    if (viewMode === 'drop-down') {
      // adjust panel position
      const $buttonPanel = $('header ul.icons');
      if ($buttonPanel.length === 0) { return; }

      const buttonPanelPos = $buttonPanel.offset();
      const myWidth = this.$().width();

      const posTop = parseInt(buttonPanelPos.top + $buttonPanel.height() - $('header.d-header').offset().top);
      const posLeft = parseInt(buttonPanelPos.left + $buttonPanel.width() - myWidth);

      this.$().css({ left: posLeft + "px", top: posTop + "px" });

      // adjust panel height
      let contentHeight = parseInt($('.panel-body-contents').height());
      const fullHeight = parseInt($(window).height());

      const offsetTop = this.$().offset().top;
      if (contentHeight + offsetTop + PANEL_BODY_MARGIN > fullHeight) {
        contentHeight = fullHeight - (offsetTop - $(window).scrollTop()) - PANEL_BODY_MARGIN;
      }
      $panelBody.height(contentHeight);
    } else {
      $panelBody.height('auto');

      const headerHeight = parseInt($('header.d-header').height() + 3);
      this.$().css({ left: "auto", top: headerHeight + "px" });
    }
  },

  _needsResize() {
    Ember.run.scheduleOnce('afterRender', this, this._resizeComponent);
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
    this._needsResize();
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
      this._needsResize();
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
