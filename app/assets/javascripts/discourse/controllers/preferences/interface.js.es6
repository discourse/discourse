import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { setDefaultHomepage } from "discourse/lib/utilities";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import {
  currentThemeKey,
  listThemes,
  previewTheme,
  setLocalTheme
} from "discourse/lib/theme-selector";
import { popupAjaxError } from "discourse/lib/ajax-error";

const USER_HOMES = {
  1: "latest",
  2: "categories",
  3: "unread",
  4: "new",
  5: "top"
};

export default Ember.Controller.extend(PreferencesTabController, {
  @computed("makeThemeDefault")
  saveAttrNames(makeDefault) {
    let attrs = [
      "locale",
      "external_links_in_new_tab",
      "dynamic_favicon",
      "enable_quoting",
      "disable_jump_reply",
      "automatically_unpin_topics",
      "allow_private_messages",
      "homepage_id"
    ];

    if (makeDefault) {
      attrs.push("theme_key");
    }

    return attrs;
  },

  preferencesController: Ember.inject.controller("preferences"),
  makeThemeDefault: true,

  @computed()
  availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  },

  @computed()
  themeKey() {
    return currentThemeKey();
  },

  userSelectableThemes: function() {
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
    const siteHome = this.siteSettings.top_menu.split("|")[0].split(",")[0];
    const userHome = USER_HOMES[this.get("model.user_option.homepage_id")];

    setDefaultHomepage(userHome || siteHome);
  },

  @computed()
  userSelectableHome() {
    let homeValues = _.invert(USER_HOMES);

    let result = [];
    this.siteSettings.top_menu.split("|").forEach(m => {
      let id = homeValues[m];
      if (id) {
        result.push({ name: I18n.t(`filters.${m}.title`), value: Number(id) });
      }
    });
    return result;
  },

  actions: {
    save() {
      this.set("saved", false);
      const makeThemeDefault = this.get("makeThemeDefault");
      if (makeThemeDefault) {
        this.set("model.user_option.theme_key", this.get("themeKey"));
      }

      return this.get("model")
        .save(this.get("saveAttrNames"))
        .then(() => {
          this.set("saved", true);

          if (!makeThemeDefault) {
            setLocalTheme(
              this.get("themeKey"),
              this.get("model.user_option.theme_key_seq")
            );
          }

          this.homeChanged();
        })
        .catch(popupAjaxError);
    }
  }
});
