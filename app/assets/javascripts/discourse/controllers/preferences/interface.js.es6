import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { setDefaultHomepage } from "discourse/lib/utilities";
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import { currentThemeKey, listThemes, previewTheme, setLocalTheme } from 'discourse/lib/theme-selector';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(PreferencesTabController, {

  @computed("makeThemeDefault")
  saveAttrNames(makeDefault) {
    let attrs = [
      'locale',
      'external_links_in_new_tab',
      'dynamic_favicon',
      'enable_quoting',
      'disable_jump_reply',
      'automatically_unpin_topics',
      'allow_private_messages',
      'user_home',
    ];

    if (makeDefault) {
      attrs.push('theme_key');
    }

    return attrs;
  },

  preferencesController: Ember.inject.controller('preferences'),
  makeThemeDefault: true,

  @computed()
  availableLocales() {
    return this.siteSettings.available_locales.split('|').map(s => ({ name: s, value: s }));
  },

  @computed()
  themeKey() {
    return currentThemeKey();
  },

  userSelectableThemes: function(){
    return listThemes(this.site);
  }.property(),

  @computed("userSelectableThemes")
  showThemeSelector(themes) {
    return themes && themes.length > 1;
  },

  @observes("themeKey")
  themeKeyChanged() {
    let key = this.get("themeKey");
    previewTheme(key);
  },
  
  homeChanged() {
    let home = Discourse.SiteSettings.top_menu.split("|")[0].split(",")[0];
    switch (Number(this.get('model.user_option.user_home'))) {
      case 1: home = "latest"; break;
      case 2: home = "categories"; break;
      case 3: home = "unread"; break;
      case 4: home = "new"; break;
      case 5: home = "top"; break;
    }
    setDefaultHomepage(home);
  },

  userSelectableHome: [
    { name: I18n.t('filters.latest.title'), value: 1 },
    { name: I18n.t('filters.categories.title'), value: 2 },
    { name: I18n.t('filters.unread.title'), value: 3 },
    { name: I18n.t('filters.new.title'), value: 4 },
    { name: I18n.t('filters.top.title'), value: 5 },
  ],

  actions: {
    save() {
      this.set('saved', false);
      const makeThemeDefault = this.get("makeThemeDefault");
      if (makeThemeDefault) {
        this.set('model.user_option.theme_key', this.get('themeKey'));
      }

      return this.get('model').save(this.get('saveAttrNames')).then(() => {
        this.set('saved', true);

        if (!makeThemeDefault) {
          setLocalTheme(this.get('themeKey'), this.get('model.user_option.theme_key_seq'));
        }
        
        this.homeChanged();

      }).catch(popupAjaxError);
    }
  }
});
