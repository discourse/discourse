import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { currentThemeId } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";
import { setDefaultColorScheme } from "admin/lib/color-scheme-manager";

export default class AdminCustomizeColorsController extends Controller {
  @service router;
  @service modal;
  @service store;
  @service dialog;
  @service toasts;
  @service session;
  @service site;
  @service siteSettings;
  @service interfaceColor;

  @tracked defaultTheme = null;

  isDefaultThemeLightColorScheme = (scheme) => {
    return this.defaultTheme?.color_scheme_id === scheme.id;
  };

  isDefaultThemeDarkColorScheme = (scheme) => {
    return this.defaultTheme?.dark_color_scheme_id === scheme.id;
  };

  _initialUserLightColorSchemeId = undefined;
  _initialUserDarkColorSchemeId = undefined;
  _initialDefaultThemeLightColorSchemeId = null;
  _initialDefaultThemeDarkColorSchemeId = null;

  canPreviewColorScheme(mode) {
    const usingDefaultTheme = currentThemeId() === this.defaultTheme?.id;

    // -1 means they're using the theme default scheme
    const usingDefaultLightScheme =
      this._initialUserLightColorSchemeId === -1 ||
      this._initialUserLightColorSchemeId ===
        this._initialDefaultThemeLightColorSchemeId;
    const usingDefaultDarkScheme =
      this._initialUserDarkColorSchemeId === -1 ||
      this._initialUserDarkColorSchemeId ===
        this._initialDefaultThemeDarkColorSchemeId;

    return (
      usingDefaultTheme &&
      ((mode === "dark" && this.isUsingDarkMode && usingDefaultDarkScheme) ||
        (mode === "light" && !this.isUsingDarkMode && usingDefaultLightScheme))
    );
  }

  get allBaseColorSchemes() {
    return this.model?.filterBy("is_base", true) || [];
  }

  _captureInitialState() {
    this._initialUserLightColorSchemeId = this.session.userColorSchemeId;
    this._initialUserDarkColorSchemeId = this.session.userDarkSchemeId;
    this._initialDefaultThemeLightColorSchemeId =
      this.defaultTheme?.color_scheme_id;
    this._initialDefaultThemeDarkColorSchemeId =
      this.defaultTheme?.dark_color_scheme_id;
  }

  get userColorSchemeDifferences() {
    const userLightDiffersFromDefault =
      this._initialUserLightColorSchemeId !== -1 &&
      this._initialUserLightColorSchemeId !==
        this._initialDefaultThemeLightColorSchemeId;

    const userDarkDiffersFromDefault =
      this._initialUserDarkColorSchemeId !== -1 &&
      this._initialUserDarkColorSchemeId !==
        this._initialDefaultThemeDarkColorSchemeId;

    return { userLightDiffersFromDefault, userDarkDiffersFromDefault };
  }

  get userPreferencesDifferFromDefaults() {
    if (!this.defaultTheme) {
      return false;
    }

    const usingDefaultTheme = currentThemeId() === this.defaultTheme.id;
    if (!usingDefaultTheme) {
      return true;
    }

    // only check color scheme preferences if using the default theme
    // because if they're not using the default theme, that's the higher priority warning
    const { userLightDiffersFromDefault, userDarkDiffersFromDefault } =
      this.userColorSchemeDifferences;

    return userLightDiffersFromDefault || userDarkDiffersFromDefault;
  }

  get preferencesWarningMessage() {
    if (!this.userPreferencesDifferFromDefaults) {
      return null;
    }

    const themeName = this.defaultTheme?.name || "default theme";
    const usingNonDefaultTheme = currentThemeId() !== this.defaultTheme?.id;

    if (usingNonDefaultTheme) {
      return {
        themeName,
        usingNonDefaultTheme: true,
      };
    }

    const { userLightDiffersFromDefault, userDarkDiffersFromDefault } =
      this.userColorSchemeDifferences;

    const affectedModes = [];
    if (userLightDiffersFromDefault) {
      affectedModes.push("light");
    }
    if (userDarkDiffersFromDefault) {
      affectedModes.push("dark");
    }

    let colorModesText;
    if (affectedModes.length === 2) {
      colorModesText = ""; // intentionally left empty
    } else if (affectedModes[0] === "light") {
      colorModesText = i18n("admin.customize.colors.light");
    } else {
      colorModesText = i18n("admin.customize.colors.dark");
    }

    return {
      themeName,
      colorModes: colorModesText,
      usingNonDefaultTheme: false,
    };
  }

  get isUsingDarkMode() {
    return (
      this.interfaceColor.darkModeForced ||
      (this.interfaceColor.colorModeIsAuto &&
        window.matchMedia("(prefers-color-scheme: dark)").matches) ||
      this.session.defaultColorSchemeIsDark
    );
  }

  get displayedPalettes() {
    return this.model.filter(
      (palette) => !palette.is_base || palette.is_builtin_default
    );
  }

  get searchableProps() {
    return ["name", "theme_name"];
  }

  get dropdownOptions() {
    return [
      {
        value: "all",
        label: i18n("admin.customize.colors.filters.all"),
        filterFn: () => true,
      },
      {
        value: "user_selectable",
        label: i18n("admin.customize.colors.filters.user_selectable"),
        filterFn: (scheme) => scheme.user_selectable,
      },
      {
        value: "from_theme",
        label: i18n("admin.customize.colors.filters.from_theme"),
        filterFn: (scheme) => scheme.theme_id,
      },
    ];
  }

<<<<<<< HEAD
=======
  get allColorPalettes() {
    return this.model.content.map((scheme) => {
      if (scheme.id === null) {
        scheme.id = scheme.base_scheme_id;
      }
      return scheme;
    });
  }

  _doInitialSort() {
    let schemes = this.model.filter((scheme) => !scheme.is_base);

    // built-in "Light (default)"
    const lightBaseScheme = this.allBaseColorSchemes.find(
      (scheme) => scheme.base_scheme_id === "Light" || scheme.name === "Light"
    );
    if (lightBaseScheme) {
      const builtInDefault = {
        ...lightBaseScheme,
        id: null,
        name: i18n("admin.customize.theme.default_light_scheme"),
        description: i18n("admin.customize.theme.default_light_scheme"),
        is_builtin_default: true,
        user_selectable: false,
        theme_id: -1,
      };
      schemes.unshift(builtInDefault);
    }

    const defaultThemeId = this.defaultTheme?.id;
    const defaultLightId = this.defaultTheme?.color_scheme_id;
    const defaultDarkId = this.defaultTheme?.dark_color_scheme_id;

    schemes.sort((a, b) => {
      // 1. Display active light
      if (
        defaultLightId === null &&
        (a.is_builtin_default || b.is_builtin_default)
      ) {
        return a.is_builtin_default ? -1 : 1;
      }
      if (
        (defaultLightId === a.id && !a.is_builtin_default) ||
        (defaultLightId === b.id && !b.is_builtin_default)
      ) {
        return defaultLightId === a.id ? -1 : 1;
      }

      // 2. Display active dark
      if (
        defaultDarkId === null &&
        (a.is_builtin_default || b.is_builtin_default)
      ) {
        return a.is_builtin_default ? -1 : 1;
      }
      if (
        (defaultDarkId === a.id && !a.is_builtin_default) ||
        (defaultDarkId === b.id && !b.is_builtin_default)
      ) {
        return defaultDarkId === a.id ? -1 : 1;
      }

      // 3. Sort by user selectable first
      if (a.user_selectable !== b.user_selectable) {
        return a.user_selectable ? -1 : 1;
      }

      // 4. Sort custom schemes (no theme) before themed schemes
      const aIsCustom = !a.theme_id && !a.is_builtin_default;
      const bIsCustom = !b.theme_id && !b.is_builtin_default;
      if (aIsCustom !== bIsCustom) {
        return aIsCustom ? -1 : 1;
      }

      // 5. Prioritize schemes from the current default theme
      const aIsFromDefaultTheme = a.theme_id === defaultThemeId;
      const bIsFromDefaultTheme = b.theme_id === defaultThemeId;
      if (aIsFromDefaultTheme !== bIsFromDefaultTheme) {
        return aIsFromDefaultTheme ? -1 : 1;
      }

      // 6. Finally, sort alphabetically by name
      return (a.originals.name || "").localeCompare(b.originals.name || "");
    });

    this._initialSortedSchemes = schemes;
    this._sortPerformed = true;
  }

  _resetSortedSchemes() {
    this._sortPerformed = false;
    this._initialSortedSchemes = [];
  }

>>>>>>> da1fd23bc0 (FIX: Allow creating new color palettes based on custom palettes)
  @action
  newColorSchemeWithBase(baseKey) {
    let base;
    if (baseKey && /^\d+$/.test(baseKey)) {
      base = this.model.content.findBy("id", baseKey);
    } else {
      base = this.allBaseColorSchemes.findBy("base_scheme_id", baseKey);
    }

    const newColorScheme = base.copy();
    newColorScheme.setProperties({
      name: i18n("admin.customize.colors.new_name"),
      base_scheme_id: base.get("base_scheme_id"),
    });
    newColorScheme.save().then(() => {
      this.model.pushObject(newColorScheme);
      newColorScheme.set("savingStatus", null);

      this.router.replaceWith("adminCustomize.colors-show", newColorScheme);
    });
  }

  @action
  newColorScheme() {
    this.modal.show(ColorSchemeSelectBaseModal, {
      model: {
        colorSchemes: this.allColorPalettes,
        newColorSchemeWithBase: this.newColorSchemeWithBase,
      },
    });
  }

  @action
  toggleUserSelectable(scheme) {
    scheme.set("user_selectable", !scheme.get("user_selectable"));
    return scheme.updateUserSelectable(scheme.get("user_selectable"));
  }

  @action
  async setAsDefaultThemePalette(scheme, mode) {
    try {
      let previewMode;
      if (scheme.is_builtin_default) {
        previewMode = "reload";
      } else if (this.canPreviewColorScheme(mode)) {
        previewMode = "live";
      } else {
        previewMode = "none";
      }

      this.defaultTheme = await setDefaultColorScheme(scheme, this.store, {
        previewMode,
        mode,
      });

      if (!this.canPreviewColorScheme(mode)) {
        const schemeName = scheme.description || scheme.name;
        const themeName = this.defaultTheme.name;
        this.toasts.success({
          data: {
            message: i18n("admin.customize.colors.set_default_success", {
              schemeName,
              themeName,
            }),
          },
          duration: 4000,
        });
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error setting default theme palette", error);
      this.dialog.alert({
        message: i18n("admin.customize.colors.default_error", {
          defaultValue: "Error setting color palette as active",
        }),
      });
    }
  }

  @action
  deleteColorScheme(scheme) {
    return new Promise((resolve, reject) => {
      this.dialog.deleteConfirm({
        title: i18n("admin.customize.colors.delete_confirm"),
        didConfirm: () => {
          return scheme
            .destroy()
            .then(() => {
              this.model.removeObject(scheme);

              resolve();
            })
            .catch(reject);
        },
        didCancel: () => {
          reject(new Error("Deletion cancelled"));
        },
      });
    });
  }
}
