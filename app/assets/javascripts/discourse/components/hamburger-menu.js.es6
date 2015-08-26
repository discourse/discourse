import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';


export default Ember.Component.extend({
  classNameBindings: ['visible::hidden', 'viewMode'],
  attributeBindings: ['style'],
  elementId: 'hamburger-menu',
  viewMode: 'dropDown',

  showClose: Ember.computed.equal('viewMode', 'slide-in'),

  @computed('viewMode')
  style(viewMode) {
    if (viewMode === 'drop-down') {
      const $buttonPanel = $('header ul.icons');

      const buttonPanelPos = $buttonPanel.offset();
      const myWidth = this.$().width();

      const posTop = parseInt(buttonPanelPos.top + $buttonPanel.height());
      const posLeft = parseInt(buttonPanelPos.left + $buttonPanel.width() - myWidth);

      return `left: ${posLeft}px; top: ${posTop}px`.htmlSafe();
    }
  },

  @computed('viewMode')
  bodyStyle(viewMode) {
    if (viewMode === 'drop-down') {
      const height = parseInt($(window).height() * 0.8)
      return `height: ${height}px`.htmlSafe();
    }
  },

  @observes('visible')
  _visibleChanged() {
    if (this.get('visible')) {
      $('.hamburger-dropdown').addClass('active');

      if ($(window).width() < 1024) {
        this.set('viewMode', 'slide-in');
      } else {
        this.set('viewMode', 'drop-down');
      }

      $('html').on('click.close-hamburger', (e) => {
        const $target = $(e.target);
        if ($target.closest('.hamburger-dropdown').length > 0) { return; }
        if ($target.closest('#hamburger-menu').length > 0) { return; }
        this.hide();
      });

    } else {
      $('.hamburger-dropdown').removeClass('active');
      $('html').off('click.close-hamburger');
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
    this.$().on('click.discourse-hamburger', 'a', () => {
      this.hide();
    });

    this.appEvents.on('dropdowns:closeAll', this, this.hide);

    $('body').on('keydown.discourse-hambuger', (e) => {
      if (e.which === 27) {
        this.hide();
      }
    });
  },

  @on('willDestroyElement')
  _removeEvents() {
    this.appEvents.off('dropdowns:closeAll', this, this.hide);
    this.$().off('click.discourse-hamburger');
    $('body').off('keydown.discourse-hambuger');
    $('html').off('click.close-hamburger');
  },

  @computed()
  categories() {
    const hideUncategorized = !this.siteSettings.allow_uncategorized_topics;
    const showSubcatList = this.siteSettings.show_subcategory_list;
    const isStaff = Discourse.User.currentProp('staff');

    return Discourse.Category.list().reject((c) => {
      if (showSubcatList && c.get('parent_category_id')) { return true; }
      if (hideUncategorized && c.get('isUncategorizedCategory') && !isStaff) { return true; }
      return false;
    });
  },

  hide() {
    this.set('visible', false);
  },

  actions: {
    close() {
      this.hide();
    },
    keyboardShortcuts() {
      this.sendAction('showKeyboardAction');
    },
    toggleMobileView() {
      Discourse.Mobile.toggleMobileView();
    }
  }
});
