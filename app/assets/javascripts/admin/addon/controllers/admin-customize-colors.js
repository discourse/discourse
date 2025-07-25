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

  @tracked defaultTheme = null;

  isDefaultThemeColorScheme = (scheme) => {
    return this.defaultTheme?.color_scheme_id === scheme.id;
  };

  @tracked _initialSortedSchemes = [];
  _initialUserColorSchemeId = undefined;
  _initialDefaultThemeColorSchemeId = null;
  _sortedOnce = false;

  get canPreviewColorScheme() {
    return currentThemeId() === this.defaultTheme?.id;
  }

  get allBaseColorSchemes() {
    return this.model?.filterBy("is_base", true) || [];
  }

  _captureInitialState() {
    this._initialUserColorSchemeId = this.session.userColorSchemeId;
    this._initialDefaultThemeColorSchemeId = this.defaultTheme?.color_scheme_id;
  }

  get changedThemePreferences() {
    // can't check against null, because the default scheme ID is null
    if (this._initialUserColorSchemeId === undefined && this.defaultTheme) {
      this._captureInitialState();
    }

    const changedColors =
      this._initialUserColorSchemeId !== this._initialDefaultThemeColorSchemeId;
    const changedTheme = this.defaultTheme?.id !== currentThemeId(this.site);

    return changedColors || changedTheme;
  }

  get sortedColorSchemes() {
    // only sort initially, this avoids position jumps when state changes on interaction
    if (!this._sortedOnce && this.model?.length > 0) {
      this._doInitialSort();
    }

    return [...this._initialSortedSchemes];
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

  _doInitialSort() {
    let schemes = this.model.filter((scheme) => !scheme.is_base);

    // built-in "Light (default)"
    const lightBaseScheme = this.allBaseColorSchemes.find(
      (scheme) => scheme.base_scheme_id === "Light" || scheme.name === "Light"
    );
    if (lightBaseScheme) {
      const builtInDefault = {
        ...lightBaseScheme,
        id: 0,
        name: i18n("admin.customize.theme.default_light_scheme"),
        description: i18n("admin.customize.theme.default_light_scheme"),
        is_builtin_default: true,
      };
      schemes.unshift(builtInDefault);
    }

    schemes.sort((a, b) => {
      const defaultId = this.defaultTheme?.color_scheme_id;

      const isDefaultA = a.is_builtin_default
        ? defaultId === null
        : a.id === defaultId;

      const isDefaultB = b.is_builtin_default
        ? defaultId === null
        : b.id === defaultId;

      if (isDefaultA !== isDefaultB) {
        return isDefaultA ? -1 : 1;
      }

      if (a.user_selectable !== b.user_selectable) {
        return a.user_selectable ? -1 : 1;
      }

      return (a.name || "").localeCompare(b.name || "");
    });

    this._initialSortedSchemes = schemes;
    this._sortedOnce = true;
  }

  _resetSortedSchemes() {
    this._sortedOnce = false;
    this._initialSortedSchemes = [];
  }

  @action
  newColorSchemeWithBase(baseKey) {
    const base = this.allBaseColorSchemes.findBy("base_scheme_id", baseKey);
    const newColorScheme = base.copy();
    newColorScheme.setProperties({
      name: i18n("admin.customize.colors.new_name"),
      base_scheme_id: base.get("base_scheme_id"),
    });
    newColorScheme.save().then(() => {
      this.model.pushObject(newColorScheme);
      newColorScheme.set("savingStatus", null);

      this._resetSortedSchemes();

      this.router.replaceWith("adminCustomize.colors-show", newColorScheme);
    });
  }

  @action
  newColorScheme() {
    this.modal.show(ColorSchemeSelectBaseModal, {
      model: {
        baseColorSchemes: this.allBaseColorSchemes,
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
  async setAsDefaultThemePalette(scheme) {
    try {
      if (this.canPreviewColorScheme) {
        this.defaultTheme = await setDefaultColorScheme(scheme, this.store);
      }

      if (!this.canPreviewColorScheme) {
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

              this._resetSortedSchemes();

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
