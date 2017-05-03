import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import { listThemes, previewTheme } from 'discourse/lib/theme-selector';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { selectDefaultTheme } from 'discourse/lib/theme-selector';

export default Ember.Controller.extend(PreferencesTabController, {

  saveAttrNames: [
    'locale',
    'external_links_in_new_tab',
    'dynamic_favicon',
    'enable_quoting',
    'disable_jump_reply',
    'automatically_unpin_topics'
  ],

  preferencesController: Ember.inject.controller('preferences'),

  @computed()
  availableLocales() {
    return this.siteSettings.available_locales.split('|').map(s => ({ name: s, value: s }));
  },

  userSelectableThemes: function(){
    return listThemes(this.site);
  }.property(),

  @observes("selectedTheme")
  themeKeyChanged() {
    let key = this.get("selectedTheme");
    this.get('preferencesController').set('selectedTheme', key);
    previewTheme(key);
  },

  actions: {
    save() {
      this.set('saved', false);
      return this.get('model').save(this.get('saveAttrNames')).then(() => {
        this.set('saved', true);
        selectDefaultTheme(this.get('selectedTheme'));
      }).catch(popupAjaxError);
    }
  }
});
