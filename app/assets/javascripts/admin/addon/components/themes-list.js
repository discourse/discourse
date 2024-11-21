import Component from "@ember/component";
import { action } from "@ember/object";
import { equal, gt, gte } from "@ember/object/computed";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import DeleteThemesConfirm from "discourse/components/modal/delete-themes-confirm";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import { COMPONENTS, THEMES } from "admin/models/theme";

const ALL_FILTER = "all";
const ACTIVE_FILTER = "active";
const INACTIVE_FILTER = "inactive";
const ENABLED_FILTER = "enabled";
const DISABLED_FILTER = "disabled";
const UPDATES_AVAILABLE_FILTER = "updates_available";

const THEMES_FILTERS = [
  { name: i18n("admin.customize.theme.all_filter"), id: ALL_FILTER },
  { name: i18n("admin.customize.theme.active_filter"), id: ACTIVE_FILTER },
  {
    name: i18n("admin.customize.theme.inactive_filter"),
    id: INACTIVE_FILTER,
  },
  {
    name: i18n("admin.customize.theme.updates_available_filter"),
    id: UPDATES_AVAILABLE_FILTER,
  },
];
const COMPONENTS_FILTERS = [
  { name: i18n("admin.customize.component.all_filter"), id: ALL_FILTER },
  {
    name: i18n("admin.customize.component.used_filter"),
    id: ACTIVE_FILTER,
  },
  {
    name: i18n("admin.customize.component.unused_filter"),
    id: INACTIVE_FILTER,
  },
  {
    name: i18n("admin.customize.component.enabled_filter"),
    id: ENABLED_FILTER,
  },
  {
    name: i18n("admin.customize.component.disabled_filter"),
    id: DISABLED_FILTER,
  },
  {
    name: i18n("admin.customize.component.updates_available_filter"),
    id: UPDATES_AVAILABLE_FILTER,
  },
];

@classNames("themes-list")
export default class ThemesList extends Component {
  @service router;
  @service modal;

  THEMES = THEMES;
  COMPONENTS = COMPONENTS;
  searchTerm = null;
  filter = ALL_FILTER;
  selectInactiveMode = false;

  @gt("themesList.length", 0) hasThemes;

  @gt("activeThemes.length", 0) hasActiveThemes;

  @gt("inactiveThemes.length", 0) hasInactiveThemes;

  @gte("themesList.length", 10) showSearchAndFilter;

  @equal("currentTab", THEMES) themesTabActive;

  @equal("currentTab", COMPONENTS) componentsTabActive;

  @equal("filter", ACTIVE_FILTER) activeFilter;
  @equal("filter", INACTIVE_FILTER) inactiveFilter;

  willRender() {
    super.willRender(...arguments);
    if (!this.showSearchAndFilter) {
      this.set("searchTerm", null);
    }
  }

  @discourseComputed("themes", "components", "currentTab")
  themesList(themes, components) {
    if (this.themesTabActive) {
      return themes;
    } else {
      return components;
    }
  }

  @discourseComputed("currentTab")
  selectableFilters() {
    if (this.themesTabActive) {
      return THEMES_FILTERS;
    } else {
      return COMPONENTS_FILTERS;
    }
  }

  @discourseComputed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default",
    "themesList.@each.markedToDelete",
    "searchTerm",
    "filter"
  )
  inactiveThemes(themes) {
    let results;
    if (this.componentsTabActive) {
      results = themes.filter(
        (theme) => theme.get("parent_themes.length") <= 0
      );
    } else {
      results = themes.filter(
        (theme) => !theme.get("user_selectable") && !theme.get("default")
      );
    }
    results = this._applyFilter(results);
    return this._searchThemes(results, this.searchTerm);
  }

  @discourseComputed("themesList.@each.markedToDelete")
  selectedThemesOrComponents() {
    return this.themesList.filter((theme) => theme.markedToDelete);
  }

  @discourseComputed("themesList.@each.markedToDelete")
  selectedCount() {
    return this.selectedThemesOrComponents.length;
  }

  @discourseComputed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default",
    "searchTerm",
    "filter"
  )
  activeThemes(themes) {
    let results;
    if (this.componentsTabActive) {
      results = themes.filter((theme) => theme.get("parent_themes.length") > 0);
    } else {
      results = themes
        .filter((theme) => theme.get("user_selectable") || theme.get("default"))
        .sort((a, b) => {
          if (a.get("default") && !b.get("default")) {
            return -1;
          } else if (b.get("default")) {
            return 1;
          }
          return a
            .get("name")
            .toLowerCase()
            .localeCompare(b.get("name").toLowerCase());
        });
    }
    results = this._applyFilter(results);
    return this._searchThemes(results, this.searchTerm);
  }

  @discourseComputed("themesList.@each.markedToDelete")
  someInactiveSelected() {
    return (
      this.selectedCount > 0 &&
      this.selectedCount !== this.inactiveThemes.length
    );
  }

  @discourseComputed("themesList.@each.markedToDelete")
  allInactiveSelected() {
    return this.selectedCount === this.inactiveThemes.length;
  }

  _searchThemes(themes, term) {
    term = term?.trim()?.toLowerCase();
    if (!term) {
      return themes;
    }
    return themes.filter(({ name }) => name.toLowerCase().includes(term));
  }

  _applyFilter(results) {
    switch (this.filter) {
      case UPDATES_AVAILABLE_FILTER: {
        return results.filterBy("isPendingUpdates");
      }
      case ENABLED_FILTER: {
        return results.filterBy("enabled");
      }
      case DISABLED_FILTER: {
        return results.filterBy("enabled", false);
      }
      default: {
        return results;
      }
    }
  }

  @bind
  toggleInactiveMode(event) {
    event?.preventDefault();
    this.inactiveThemes.forEach((theme) => theme.set("markedToDelete", false));
    this.toggleProperty("selectInactiveMode");
  }

  @action
  changeView(newTab) {
    if (newTab !== this.currentTab) {
      this.set("selectInactiveMode", false);
      this.set("filter", ALL_FILTER);
      this.router.transitionTo("adminCustomizeThemes", newTab);
    }
  }

  @action
  navigateToTheme(theme) {
    this.router.transitionTo("adminCustomizeThemes.show", theme);
  }

  @action
  toggleAllInactive() {
    const markedToDelete = this.selectedCount === 0;
    this.inactiveThemes.forEach((theme) =>
      theme.set("markedToDelete", markedToDelete)
    );
  }

  @action
  deleteConfirmation() {
    this.modal.show(DeleteThemesConfirm, {
      model: {
        selectedThemesOrComponents: this.selectedThemesOrComponents,
        type: this.themesTabActive ? "themes" : "components",
        refreshAfterDelete: () => {
          this.set("selectInactiveMode", false);
          if (this.themesTabActive) {
            this.set(
              "themes",
              this.themes.filter(
                (theme) => !this.selectedThemesOrComponents.includes(theme)
              )
            );
          } else {
            this.set(
              "components",
              this.components.filter(
                (component) =>
                  !this.selectedThemesOrComponents.includes(component)
              )
            );
          }
        },
      },
    });
  }
}
