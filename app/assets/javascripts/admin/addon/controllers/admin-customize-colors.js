import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ColorSchemeSelectBaseModal from "admin/components/modal/color-scheme-select-base";

export default class AdminCustomizeColorsController extends Controller {
  @service router;
  @service modal;
  @service store;
  @service dialog;

  @tracked defaultTheme = null;
  @tracked filterValue = "";
  @tracked typeFilter = "all";

  isDefaultThemeColorScheme = (scheme) => {
    return this.defaultTheme?.color_scheme_id === scheme.id;
  };

  @discourseComputed("model.@each.id")
  baseColorScheme() {
    return this.model.findBy("is_base", true);
  }

  @discourseComputed("model.@each.id")
  baseColorSchemes() {
    return this.model.filterBy("is_base", true);
  }

  @discourseComputed("baseColorScheme")
  baseColors(baseColorScheme) {
    const baseColorsHash = EmberObject.create({});
    baseColorScheme.get("colors").forEach((color) => {
      baseColorsHash.set(color.get("name"), color);
    });
    return baseColorsHash;
  }

  @discourseComputed("model.@each.id", "filterValue", "typeFilter")
  filteredColorSchemes() {
    let schemes = this.model.filter((scheme) => !scheme.is_base);

    if (this.typeFilter !== "all") {
      if (this.typeFilter === "user_selectable") {
        schemes = schemes.filter((scheme) => scheme.user_selectable);
      } else if (this.typeFilter === "from_theme") {
        schemes = schemes.filter((scheme) => scheme.theme_id);
      }
    }

    // Filter by search term
    if (this.filterValue) {
      const term = this.filterValue.toLowerCase();
      schemes = schemes.filter((scheme) => {
        const nameMatches = scheme.name?.toLowerCase().includes(term);
        const descriptionMatches = scheme.description
          ?.toLowerCase()
          .includes(term);
        const themeMatches = scheme.theme_name?.toLowerCase().includes(term);
        return nameMatches || descriptionMatches || themeMatches;
      });
    }

    return schemes;
  }

  @discourseComputed("filteredColorSchemes")
  showFilters() {
    return this.model.filter((scheme) => !scheme.is_base).length > 8;
  }

  @discourseComputed("filterValue", "typeFilter")
  showBuiltInDefault() {
    if (this.typeFilter === "from_theme") {
      return false;
    }

    if (this.typeFilter === "user_selectable") {
      return false;
    }

    // check if it matches "Light (default)"
    if (this.filterValue) {
      const term = this.filterValue.toLowerCase();
      const lightDefault = "light (default)";
      return lightDefault.includes(term);
    }

    return true;
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
    const base = this.baseColorSchemes.findBy("base_scheme_id", baseKey);
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
        baseColorSchemes: this.baseColorSchemes,
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
  setAsDefaultThemePalette(scheme) {
    this.store.findAll("theme").then((themes) => {
      const defaultTheme = themes.findBy("default", true);
      if (defaultTheme) {
        // null is the pre-seeded scheme
        const schemeId = scheme ? scheme.get("id") : null;
        defaultTheme.set("color_scheme_id", schemeId);

        this.set("defaultTheme", defaultTheme);

        defaultTheme.saveChanges("color_scheme_id").then(() => {
          // refresh to show changes
          window.location.reload();
        });
      }
    });
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
