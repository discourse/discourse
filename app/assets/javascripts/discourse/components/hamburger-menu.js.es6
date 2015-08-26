import { default as computed, on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: ['visible::slideright'],
  elementId: 'hamburger-menu',

  visibilityChanged: function(){
    if(this.get("visible")) {
     $('html').on('click.close-humburger', (e) => {

        if (this.get('isDestroyed')) {
          $('html').off('click.close-humburger');
          return true;
        }

        const $target = $(e.target);
        if ($target.closest('.dropdown.categories').length > 0) {
          return;
        }

        this.set("visible", false);
        $('html').off('click.close-humburger');
        return true;

      });
    } else {
      $('html').off('click.close-humburger');
    }
  }.observes("visible"),

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
      this.set('visible', false);
    });

    $('body').on('keydown.discourse-hambuger', (e) => {
      if (e.which === 27) {
        this.set('visible', false);
      }
    });
  },

  @on('willDestroyElement')
  _removeEvents() {
    this.$().off('click.discourse-hamburger');
    $('body').off('keydown.discourse-hambuger');
    $('body').off('click.close-humburger');
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

  actions: {
    close() {
      this.set('visible', false);
    },
    keyboardShortcuts() {
      this.sendAction('showKeyboardAction');
    },
    toggleMobileView() {
      Discourse.Mobile.toggleMobileView();
    }
  }
});
