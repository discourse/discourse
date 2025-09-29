import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { currentThemeId } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";
import { setDefaultColorScheme } from "admin/lib/color-scheme-manager";

export default class AdminConfigColorPalettesIndexController extends Controller {
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
    return this.model?.filter((scheme) => scheme.is_base) || [];
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

  @action
  newColorSchemeWithBase(baseKey) {
    const base = this.model.find((palette) => palette.id === baseKey);

    const newColorScheme = base.copy();
    newColorScheme.setProperties({
      name: i18n("admin.customize.colors.new_name"),
      base_scheme_id: base.get("id"),
    });
    newColorScheme.save().then(() => {
      newColorScheme.colors.forEach((color) => {
        color.default_hex = color.originals.hex;
      });
      this.model.pushObject(newColorScheme);
      newColorScheme.set("savingStatus", null);

      this.router.replaceWith("adminConfig.colorPalettes.show", newColorScheme);
    });
  }

  @action
  newColorScheme() {
    // If a base palette exists in database, it should be removed from the list in the modal as potential base to not display duplicated names.
    const deduplicatedColorPalettes = this.model.filter((base) => {
      if (
        base.id < 0 &&
        this.model.find((palette) => {
          return (
            palette.name === base.name &&
            palette.base_scheme_id === base.base_scheme_id &&
            palette.id > 0
          );
        })
      ) {
        return false;
      }
      return true;
    });

    this.modal.show(ColorSchemeSelectBaseModal, {
      model: {
        colorSchemes: deduplicatedColorPalettes,
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
