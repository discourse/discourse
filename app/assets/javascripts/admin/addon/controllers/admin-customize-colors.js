import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";
import { setDefaultColorScheme } from "admin/lib/color-scheme-manager";

export default class AdminCustomizeColorsController extends Controller {
  @service router;
  @service modal;
  @service store;
  @service dialog;

  @tracked defaultTheme = null;
  @tracked filterValue = "";
  @tracked typeFilter = "all";
  @tracked isSettingDefault = false;

  isDefaultThemeColorScheme = (scheme) => {
    return this.defaultTheme?.color_scheme_id === scheme.id;
  };

  get allBaseColorSchemes() {
    return this.model?.filterBy("is_base", true) || [];
  }

  get filteredColorSchemes() {
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
      };
      schemes.unshift(builtInDefault);
    }

    if (this.typeFilter !== "all") {
      if (this.typeFilter === "user_selectable") {
        schemes = schemes.filter((scheme) => scheme.user_selectable);
      } else if (this.typeFilter === "from_theme") {
        schemes = schemes.filter((scheme) => scheme.theme_id);
      }
    }

    if (this.filterValue) {
      const term = this.filterValue.toLowerCase();
      schemes = schemes.filter((scheme) => {
        const nameMatches = scheme.name?.toLowerCase().includes(term);
        const themeMatches = scheme.theme_name?.toLowerCase().includes(term);
        return nameMatches || themeMatches;
      });
    }

    // active first, then user selectable, then alpha
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

    return schemes;
  }

  get showFilters() {
    return this.model.filter((scheme) => !scheme.is_base).length > 8;
  }

  get typeFilterOptions() {
    return [
      {
        value: "all",
        label: i18n("admin.customize.colors.filters.all"),
      },
      {
        value: "user_selectable",
        label: i18n("admin.customize.colors.filters.user_selectable"),
      },
      {
        value: "from_theme",
        label: i18n("admin.customize.colors.filters.from_theme"),
      },
    ];
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
    scheme.updateUserSelectable(scheme.get("user_selectable"));
  }

  @action
  async setAsDefaultThemePalette(scheme) {
    this.isSettingDefault = true;

    try {
      this.defaultTheme = await setDefaultColorScheme(scheme, this.store);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error setting default theme palette", error);
      this.dialog.alert({
        message: i18n("admin.customize.colors.default_error", {
          defaultValue: "Error setting color palette as active",
        }),
      });
    } finally {
      this.isSettingDefault = false;
    }
  }

  @action
  deleteColorScheme(scheme) {
    return this.dialog.deleteConfirm({
      title: i18n("admin.customize.colors.delete_confirm"),
      didConfirm: () => {
        return scheme.destroy().then(() => {
          this.model.removeObject(scheme);
        });
      },
    });
  }

  @action
  onFilterChange(event) {
    this.filterValue = event.target?.value || "";
  }

  @action
  onTypeFilterChange(value) {
    this.typeFilter = value;
  }

  @action
  resetFilters() {
    this.filterValue = "";
    this.typeFilter = "all";
    document.querySelector(".admin-filter__input")?.focus();
  }
}
