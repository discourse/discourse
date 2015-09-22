import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import { headerHeight } from 'discourse/views/header';

const PANEL_BODY_MARGIN = 30;
const mutationSupport = !!window['MutationObserver'];

export default Ember.Component.extend({
  classNameBindings: [':menu-panel', 'visible::hidden', 'viewMode'],

  showClose: Ember.computed.equal('viewMode', 'slide-in'),

  _layoutComponent() {
    if (!this.get('visible')) { return; }

    const $window = $(window);
    let width = this.get('maxWidth') || 300;
    const windowWidth = parseInt($window.width());

    if ((windowWidth - width) < 50) {
      width = windowWidth - 50;
    }

    const viewMode = this.get('viewMode');
    const $panelBody = this.$('.panel-body');
    let contentHeight = parseInt(this.$('.panel-body-contents').height());

    if (viewMode === 'drop-down') {
      const $buttonPanel = $('header ul.icons');
      if ($buttonPanel.length === 0) { return; }

      // These values need to be set here, not in the css file - this is to deal with the
      // possibility of the window being resized and the menu changing from .slide-in to .drop-down.
      this.$().css({ top: '100%', height: 'auto' });

      // adjust panel height
      const fullHeight = parseInt($window.height());
      const offsetTop = this.$().offset().top;
      const scrollTop = $window.scrollTop();

      if (contentHeight + (offsetTop - scrollTop) + PANEL_BODY_MARGIN > fullHeight) {
        contentHeight = fullHeight - (offsetTop - scrollTop) - PANEL_BODY_MARGIN;
      }
      $panelBody.height(contentHeight);
      $('body').addClass('drop-down-visible');
    } else {
      const menuTop = headerHeight();

      let height;
      const winHeight = $(window).height() - 16;
      if ((menuTop + contentHeight) < winHeight) {
        height = contentHeight + "px";
      } else {
        height = winHeight - menuTop;
      }

      $panelBody.height('100%');
      this.$().css({ top: menuTop + "px", height });
      $('body').removeClass('drop-down-visible');
    }

    this.$().width(width);
  },

  @computed('force')
  viewMode() {
    const force = this.get('force');
    if (force) { return force; }

    const headerWidth = $('#main-outlet .container').width() || 1100;
    const screenWidth = $(window).width();
    const remaining = parseInt((screenWidth - headerWidth) / 2);

    return (remaining < 50) ? 'slide-in' : 'drop-down';
  },

  @observes('viewMode', 'visible')
  _visibleChanged() {
    if (this.get('visible')) {
      // Allow us to hook into things being shown
      Ember.run.scheduleOnce('afterRender', () => this.sendAction('onVisible'));
      $('html').on('click.close-menu-panel', (e) => {
        const $target = $(e.target);
        if ($target.closest('.header-dropdown-toggle').length > 0) { return; }
        if ($target.closest('.menu-panel').length > 0) { return; }
        this.hide();
      });
      this.performLayout();
      this._watchSizeChanges();

      // iOS does not handle scroll events well
      if (!this.capabilities.touch) {
        $(window).on('scroll.discourse-menu-panel', () => this.performLayout());
      }
    } else {
      Ember.run.scheduleOnce('afterRender', () => this.sendAction('onHidden'));
      $('html').off('click.close-menu-panel');
      $(window).off('scroll.discourse-menu-panel');
      this._stopWatchingSize();
      $('body').removeClass('drop-down-visible');
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

  performLayout() {
    Ember.run.scheduleOnce('afterRender', this, this._layoutComponent);
  },

  _watchSizeChanges() {
    if (mutationSupport) {
      this._observer.disconnect();
      this._observer.observe(this.element, { childList: true, subtree: true });
    } else {
      clearInterval(this._resizeInterval);
      this._resizeInterval = setInterval(() => {
        Ember.run(() => {
          const $panelBodyContents = this.$('.panel-body-contents');

          if ($panelBodyContents.length) {
            const contentHeight = parseInt($panelBodyContents.height());
            if (contentHeight !== this._lastHeight) { this.performLayout(); }
            this._lastHeight = contentHeight;
          }
        });
      }, 500);
    }
  },

  _stopWatchingSize() {
    if (mutationSupport) {
      this._observer.disconnect();
    } else {
      clearInterval(this._resizeInterval);
    }
  },

  @on('didInsertElement')
  _bindEvents() {
    this.$().on('click.discourse-menu-panel', 'a', e => {
      if (e.metaKey || e.ctrlKey || e.shiftKey) { return; }
      const $target = $(e.target);
      if ($target.data('ember-action') || $target.closest('.search-link').length > 0) { return; }
      this.hide();
    });

    this.appEvents.on('dropdowns:closeAll', this, this.hide);
    this.appEvents.on('dom:clean', this, this.hide);

    $('body').on('keydown.discourse-menu-panel', e => {
      if (e.which === 27) {
        this.hide();
      }
    });

    $(window).on('resize.discourse-menu-panel', () => {
      this.propertyDidChange('viewMode');
      this.performLayout();
    });

    if (mutationSupport) {
      this._observer = new MutationObserver(() => {
        Ember.run(() => this.performLayout());
      });
    }

    this.propertyDidChange('viewMode');
  },

  @on('willDestroyElement')
  _removeEvents() {
    this.appEvents.off('dom:clean', this, this.hide);
    this.appEvents.off('dropdowns:closeAll', this, this.hide);
    this.$().off('click.discourse-menu-panel');
    $('body').off('keydown.discourse-menu-panel');
    $('html').off('click.close-menu-panel');
    $(window).off('resize.discourse-menu-panel');
    $(window).off('scroll.discourse-menu-panel');
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
