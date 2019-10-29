import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { setDefaultHomepage } from "discourse/lib/utilities";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import {
  listThemes,
  previewTheme,
  setLocalTheme
} from "discourse/lib/theme-selector";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  safariHacksDisabled,
  isiPad,
  iOSWithVisualViewport
} from "discourse/lib/utilities";

const USER_HOMES = {
  1: "latest",
  2: "categories",
  3: "unread",
  4: "new",
  5: "top"
};

const TEXT_SIZES = ["smaller", "normal", "larger", "largest"];
const TITLE_COUNT_MODES = ["notifications", "contextual"];

export default Controller.extend(PreferencesTabController, {
  @computed("makeThemeDefault")
  saveAttrNames(makeDefault) {
    let attrs = [
      "locale",
      "external_links_in_new_tab",
      "dynamic_favicon",
      "enable_quoting",
      "enable_defer",
      "automatically_unpin_topics",
      "allow_private_messages",
      "homepage_id",
      "hide_profile_and_presence",
      "text_size",
      "title_count_mode"
    ];

    if (makeDefault) {
      attrs.push("theme_ids");
    }

    return attrs;
  },

  preferencesController: inject("preferences"),

  @computed()
  isiPad() {
    // TODO: remove this preference checkbox when iOS adoption > 90%
    // (currently only applies to iOS 12 and below)
    return isiPad() && !iOSWithVisualViewport();
  },

  @computed()
  disableSafariHacks() {
    return safariHacksDisabled();
  },

  @computed()
  availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  },

  @computed
  textSizes() {
    return TEXT_SIZES.map(value => {
      return { name: I18n.t(`user.text_size.${value}`), value };
    });
  },

  @computed
  titleCountModes() {
    return TITLE_COUNT_MODES.map(value => {
      return { name: I18n.t(`user.title_count_mode.${value}`), value };
    });
  },

  @computed
  userSelectableThemes() {
    return listThemes(this.site);
  },

  @computed("userSelectableThemes")
  showThemeSelector(themes) {
    return themes && themes.length > 1;
  },

  @observes("themeId")
  themeIdChanged() {
    const id = this.themeId;
    previewTheme([id]);
  },

  @computed("model.user_option.theme_ids", "themeId")
  showThemeSetDefault(userOptionThemes, selectedTheme) {
    return !userOptionThemes || userOptionThemes[0] !== selectedTheme;
  },

  @computed("model.user_option.text_size", "textSize")
  showTextSetDefault(userOptionTextSize, selectedTextSize) {
    return userOptionTextSize !== selectedTextSize;
  },

  homeChanged() {
    const siteHome = this.siteSettings.top_menu.split("|")[0].split(",")[0];
    const userHome = USER_HOMES[this.get("model.user_option.homepage_id")];

    setDefaultHomepage(userHome || siteHome);
  },

  @computed()
  userSelectableHome() {
    let homeValues = {};
    Object.keys(USER_HOMES).forEach(newValue => {
      const newKey = USER_HOMES[newValue];
      homeValues[newKey] = newValue;
    });

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
      const makeThemeDefault = this.makeThemeDefault;
      if (makeThemeDefault) {
        this.set("model.user_option.theme_ids", [this.themeId]);
      }

      const makeTextSizeDefault = this.makeTextSizeDefault;
      if (makeTextSizeDefault) {
        this.set("model.user_option.text_size", this.textSize);
      }

      return this.model
        .save(this.saveAttrNames)
        .then(() => {
          this.set("saved", true);

          if (makeThemeDefault) {
            setLocalTheme([]);
          } else {
            setLocalTheme(
              [this.themeId],
              this.get("model.user_option.theme_key_seq")
            );
          }
          if (makeTextSizeDefault) {
            this.model.updateTextSizeCookie(null);
          } else {
            this.model.updateTextSizeCookie(this.textSize);
          }

          this.homeChanged();

          if (this.isiPad) {
            if (safariHacksDisabled() !== this.disableSafariHacks) {
              Discourse.set("assetVersion", "forceRefresh");
            }
            localStorage.setItem(
              "safari-hacks-disabled",
              this.disableSafariHacks.toString()
            );
          }
        })
        .catch(popupAjaxError);
    },

    selectTextSize(newSize) {
      const classList = document.documentElement.classList;

      TEXT_SIZES.forEach(name => {
        const className = `text-size-${name}`;
        if (newSize === name) {
          classList.add(className);
        } else {
          classList.remove(className);
        }
      });

      // Force refresh when leaving this screen
      Discourse.set("assetVersion", "forceRefresh");
    }
  }
});
