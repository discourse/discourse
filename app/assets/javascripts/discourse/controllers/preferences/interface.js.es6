import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import { listThemes, previewTheme, setLocalTheme } from 'discourse/lib/theme-selector';
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
      'automatically_unpin_topics'
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

  userSelectableThemes: function(){
    return listThemes(this.site);
  }.property(),

  @computed("userSelectableThemes")
  showThemeSelector(themes) {
    return themes && themes.length > 1;
  },

  @observes("model.user_option.theme_key")
  themeKeyChanged() {
    let key = this.get("model.user_option.theme_key");
    previewTheme(key);
  },

  actions: {
    save() {
      this.set('saved', false);
      const makeThemeDefault = this.get("makeThemeDefault");

      return this.get('model').save(this.get('saveAttrNames')).then(() => {
        this.set('saved', true);

        if (!makeThemeDefault) {
          setLocalTheme(this.get('model.user_option.theme_key'), this.get('model.user_option.theme_key_seq'));
        }

      }).catch(popupAjaxError);
    }
  }
});
