import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { reload } from "discourse/helpers/page-reloader";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  listColorSchemes,
  loadColorSchemeStylesheet,
  updateColorSchemeCookie,
} from "discourse/lib/color-scheme-picker";
import { propertyEqual } from "discourse/lib/computed";
import { INTERFACE_COLOR_MODES } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import {
  currentThemeId,
  listThemes,
  setLocalTheme,
} from "discourse/lib/theme-selector";
import { setDefaultHomepage } from "discourse/lib/utilities";
import { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

// same as UserOption::HOMEPAGES
const USER_HOMES = {
  1: "latest",
  2: "categories",
  3: "unread",
  4: "new",
  5: "top",
  6: "bookmarks",
  7: "unseen",
  8: "hot",
};

const TEXT_SIZES = ["smallest", "smaller", "normal", "larger", "largest"];
const TITLE_COUNT_MODES = ["notifications", "contextual"];

export default class InterfaceController extends Controller {
  @service interfaceColor;
  @service session;
  @controller("preferences") preferencesController;

  @tracked selectedInterfaceColorModeId = null;
  currentThemeId = currentThemeId();
  previewingColorScheme = false;
  selectedDarkColorSchemeId = null;
  makeColorSchemeDefault = true;

  @propertyEqual("model.id", "currentUser.id") canPreviewColorScheme;
  @propertyEqual("model.id", "currentUser.id") isViewingOwnProfile;
  subpageTitle = i18n("user.preferences_nav.interface");

  init() {
    super.init(...arguments);
    this.set("selectedDarkColorSchemeId", this.session.userDarkSchemeId);
    this.set("selectedColorSchemeId", this.getSelectedColorSchemeId());
  }

  @discourseComputed("makeThemeDefault")
  saveAttrNames(makeThemeDefault) {
    let attrs = [
      "locale",
      "external_links_in_new_tab",
      "dynamic_favicon",
      "enable_quoting",
      "enable_smart_lists",
      "enable_defer",
      "automatically_unpin_topics",
      "allow_private_messages",
      "enable_allowed_pm_users",
      "homepage_id",
      "hide_presence",
      "text_size",
      "title_count_mode",
      "skip_new_user_tips",
      "seen_popups",
      "color_scheme_id",
      "dark_scheme_id",
      "bookmark_auto_delete_preference",
      "interface_color_mode",
      "enable_markdown_monospace_font",
    ];

    if (makeThemeDefault) {
      attrs.push("theme_ids");
    }

    return attrs;
  }

  @discourseComputed()
  availableLocales() {
    return this.siteSettings.available_locales;
  }

  @discourseComputed("currentThemeId")
  defaultDarkSchemeId(themeId) {
    const theme = this.userSelectableThemes?.findBy("id", themeId);
    return theme?.dark_color_scheme_id || -1;
  }

  @discourseComputed
  textSizes() {
    return TEXT_SIZES.map((value) => {
      return { name: i18n(`user.text_size.${value}`), value };
    });
  }

  @computed("model.user_option.homepage_id", "userSelectableHome.[]")
  get homepageId() {
    return (
      this.model.user_option.homepage_id ||
      this.userSelectableHome.firstObject.value
    );
  }

  @discourseComputed
  titleCountModes() {
    return TITLE_COUNT_MODES.map((value) => {
      return { name: i18n(`user.title_count_mode.${value}`), value };
    });
  }

  @discourseComputed
  bookmarkAfterNotificationModes() {
    return Object.keys(AUTO_DELETE_PREFERENCES).map((key) => {
      return {
        value: AUTO_DELETE_PREFERENCES[key],
        name: i18n(`bookmarks.auto_delete_preference.${key.toLowerCase()}`),
      };
    });
  }

  @discourseComputed
  userSelectableThemes() {
    return listThemes(this.site);
  }

  @discourseComputed("userSelectableThemes")
  showThemeSelector(themes) {
    return themes && themes.length > 1;
  }

  @discourseComputed("themeId")
  themeIdChanged(themeId) {
    if (this.currentThemeId === -1) {
      this.set("currentThemeId", themeId);
      return false;
    } else {
      return this.currentThemeId !== themeId;
    }
  }

  @discourseComputed
  userSelectableColorSchemes() {
    return listColorSchemes(this.site);
  }

  @discourseComputed(
    "userSelectableThemes",
    "userSelectableColorSchemes",
    "themeId"
  )
  currentSchemeCanBeSelected(userThemes, userColorSchemes, themeId) {
    if (!userThemes || !themeId) {
      return false;
    }

    const theme = userThemes.findBy("id", themeId);
    if (!theme) {
      return false;
    }

    return userColorSchemes.findBy("id", theme.color_scheme_id);
  }

  @discourseComputed("model.user_option.theme_ids", "themeId")
  showThemeSetDefault(userOptionThemes, selectedTheme) {
    return !userOptionThemes || userOptionThemes[0] !== selectedTheme;
  }

  @discourseComputed("model.user_option.text_size", "textSize")
  showTextSetDefault(userOptionTextSize, selectedTextSize) {
    return userOptionTextSize !== selectedTextSize;
  }

  homeChanged() {
    const siteHome = this.siteSettings.top_menu.split("|")[0].split(",")[0];

    if (this.model.canPickThemeWithCustomHomepage) {
      USER_HOMES[-1] = "custom";
    }

    const userHome = USER_HOMES[this.get("model.user_option.homepage_id")];

    setDefaultHomepage(userHome || siteHome);
  }

  @discourseComputed()
  userSelectableHome() {
    let homeValues = {};
    Object.keys(USER_HOMES).forEach((newValue) => {
      const newKey = USER_HOMES[newValue];
      homeValues[newKey] = newValue;
    });

    let result = [];

    if (this.model.canPickThemeWithCustomHomepage) {
      result.push({
        name: i18n("user.homepage.default"),
        value: -1,
      });
    }

    const availableIds = this.siteSettings.top_menu.split("|");
    const userHome = USER_HOMES[this.get("model.user_option.homepage_id")];

    if (userHome && !availableIds.includes(userHome)) {
      availableIds.push(USER_HOMES[this.homepageId]);
    }

    availableIds.forEach((m) => {
      let id = homeValues[m];
      if (id) {
        result.push({ name: i18n(`filters.${m}.title`), value: Number(id) });
      }
    });

    return result;
  }

  @discourseComputed("selectedDarkColorSchemeId")
  showInterfaceColorModeSelector(selectedDarkColorSchemeId) {
    return this.defaultDarkSchemeId > 0 || selectedDarkColorSchemeId > 0;
  }

  @discourseComputed
  userSelectableDarkColorSchemes() {
    return listColorSchemes(this.site, {
      darkOnly: true,
    });
  }

  @discourseComputed(
    "userSelectableColorSchemes",
    "userSelectableDarkColorSchemes"
  )
  showColorSchemeSelector() {
    return (
      this.showLightColorSchemeSelector ||
      this.showDarkColorSchemeSelector ||
      this.showInterfaceColorModeSelector
    );
  }

  @discourseComputed("userSelectableColorSchemes")
  showLightColorSchemeSelector(lightSchemes) {
    return lightSchemes && lightSchemes.length > 1;
  }

  @discourseComputed("userSelectableDarkColorSchemes")
  showDarkColorSchemeSelector(darkSchemes) {
    return darkSchemes && darkSchemes.length > 1;
  }

  get interfaceColorModes() {
    return [
      {
        id: INTERFACE_COLOR_MODES.AUTO,
        name: i18n("user.color_schemes.interface_modes.auto"),
      },
      {
        id: INTERFACE_COLOR_MODES.LIGHT,
        name: i18n("user.color_schemes.interface_modes.light"),
      },
      {
        id: INTERFACE_COLOR_MODES.DARK,
        name: i18n("user.color_schemes.interface_modes.dark"),
      },
    ];
  }

  get selectedInterfaceColorMode() {
    if (this.selectedInterfaceColorModeId) {
      return this.selectedInterfaceColorModeId;
    }
    if (this.isViewingOwnProfile) {
      if (this.interfaceColor.colorModeIsAuto) {
        return INTERFACE_COLOR_MODES.AUTO;
      }
      if (this.interfaceColor.colorModeIsLight) {
        return INTERFACE_COLOR_MODES.LIGHT;
      }
      if (this.interfaceColor.colorModeIsDark) {
        return INTERFACE_COLOR_MODES.DARK;
      }
    }
    return this.model.user_option.interface_color_mode;
  }

  getSelectedColorSchemeId() {
    if (!this.session.userColorSchemeId) {
      return;
    }

    const theme = this.userSelectableThemes?.findBy("id", this.themeId);

    // we don't want to display the numeric ID of a scheme
    // when it is set by the theme but not marked as user selectable
    if (
      theme?.color_scheme_id === this.session.userColorSchemeId &&
      !this.userSelectableColorSchemes.findBy(
        "id",
        this.session.userColorSchemeId
      )
    ) {
      return;
    } else {
      return this.session.userColorSchemeId;
    }
  }

  @action
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

    if (!this.showColorSchemeSelector) {
      this.set("model.user_option.color_scheme_id", null);
      this.set("model.user_option.dark_scheme_id", null);
    } else if (this.makeColorSchemeDefault) {
      this.set("model.user_option.color_scheme_id", this.selectedColorSchemeId);
      this.set(
        "model.user_option.dark_scheme_id",
        this.selectedDarkColorSchemeId
      );
      if (this.selectedInterfaceColorModeId) {
        this.set(
          "model.user_option.interface_color_mode",
          this.selectedInterfaceColorModeId
        );
      }
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

        if (this.makeColorSchemeDefault) {
          updateColorSchemeCookie(null);
          updateColorSchemeCookie(null, { dark: true });
        } else {
          updateColorSchemeCookie(this.selectedColorSchemeId);

          if (
            this.defaultDarkSchemeId > 0 &&
            this.selectedDarkColorSchemeId === this.defaultDarkSchemeId
          ) {
            updateColorSchemeCookie(null, { dark: true });
          } else {
            updateColorSchemeCookie(this.selectedDarkColorSchemeId, {
              dark: true,
            });
          }
        }

        if (this.selectedInterfaceColorModeId) {
          if (this.isViewingOwnProfile) {
            const modeId = this.selectedInterfaceColorModeId;
            if (modeId === INTERFACE_COLOR_MODES.AUTO) {
              this.interfaceColor.useAutoMode();
            } else if (modeId === INTERFACE_COLOR_MODES.LIGHT) {
              this.interfaceColor.forceLightMode();
            } else if (modeId === INTERFACE_COLOR_MODES.DARK) {
              this.interfaceColor.forceDarkMode();
            }
          }
          this.selectedInterfaceColorModeId = null;
        }

        this.homeChanged();

        if (this.themeId && this.themeId !== this.currentThemeId) {
          reload();
        }
      })
      .catch(popupAjaxError);
  }

  @action
  selectTextSize(newSize) {
    const classList = document.documentElement.classList;

    TEXT_SIZES.forEach((name) => {
      const className = `text-size-${name}`;
      if (newSize === name) {
        classList.add(className);
      } else {
        classList.remove(className);
      }
    });

    // Force refresh when leaving this screen
    this.session.requiresRefresh = true;
    this.set("textSize", newSize);
  }

  @action
  loadColorScheme(colorSchemeId) {
    this.setProperties({
      selectedColorSchemeId: colorSchemeId,
      previewingColorScheme: this.isViewingOwnProfile,
    });

    if (!this.isViewingOwnProfile) {
      return;
    }

    if (colorSchemeId < 0) {
      const defaultTheme = this.userSelectableThemes.findBy("id", this.themeId);

      if (defaultTheme && defaultTheme.color_scheme_id) {
        colorSchemeId = defaultTheme.color_scheme_id;
      }
    }
    loadColorSchemeStylesheet(colorSchemeId, this.themeId);
    if (this.selectedDarkColorSchemeId === -1) {
      // set this same scheme for dark mode preview when dark scheme is disabled
      loadColorSchemeStylesheet(colorSchemeId, this.themeId, true);
    }
  }

  @action
  loadDarkColorScheme(colorSchemeId) {
    this.setProperties({
      selectedDarkColorSchemeId: colorSchemeId,
      previewingColorScheme: this.isViewingOwnProfile,
    });

    if (!this.isViewingOwnProfile) {
      return;
    }

    if (colorSchemeId === -1) {
      // load preview of regular scheme when dark scheme is disabled
      loadColorSchemeStylesheet(this.selectedColorSchemeId, this.themeId, true);
      this.session.set("darkModeAvailable", false);
    } else {
      loadColorSchemeStylesheet(colorSchemeId, this.themeId, true);
      this.session.set("darkModeAvailable", true);
    }
  }

  @action
  selectColorMode(modeId) {
    this.selectedInterfaceColorModeId = modeId;
    this.set("previewingColorScheme", this.isViewingOwnProfile);
  }

  @action
  undoColorSchemePreview() {
    this.setProperties({
      selectedColorSchemeId: this.session.userColorSchemeId,
      selectedDarkColorSchemeId: this.session.userDarkSchemeId,
      selectedInterfaceColorModeId: null,
      previewingColorScheme: false,
    });
    const darkStylesheet = document.querySelector("link#cs-preview-dark"),
      lightStylesheet = document.querySelector("link#cs-preview-light");
    if (darkStylesheet) {
      darkStylesheet.remove();
    }

    if (lightStylesheet) {
      lightStylesheet.remove();
    }
  }

  @action
  resetSeenUserTips() {
    this.model.set("user_option.skip_new_user_tips", false);
    this.model.set("user_option.seen_popups", null);
    return this.model.save(["skip_new_user_tips", "seen_popups"]);
  }
}
