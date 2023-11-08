import Component from "@ember/component";
import { action } from "@ember/object";
import { equal, gt, gte } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import DeleteThemesConfirm from "discourse/components/modal/delete-themes-confirm";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { COMPONENTS, THEMES } from "admin/models/theme";

@classNames("themes-list")
export default class ThemesList extends Component {
  @service router;
  @service modal;

  THEMES = THEMES;
  COMPONENTS = COMPONENTS;
  filterTerm = null;
  selectInactiveMode = false;

  @gt("themesList.length", 0) hasThemes;

  @gt("activeThemes.length", 0) hasActiveThemes;

  @gt("inactiveThemes.length", 0) hasInactiveThemes;

  @gte("themesList.length", 10) showFilter;

  @equal("currentTab", THEMES) themesTabActive;

  @equal("currentTab", COMPONENTS) componentsTabActive;

  @discourseComputed("themes", "components", "currentTab")
  themesList(themes, components) {
    if (this.themesTabActive) {
      return themes;
    } else {
      return components;
    }
  }

  @discourseComputed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default",
    "themesList.@each.markedToDelete",
    "filterTerm"
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
    return this._filterThemes(results, this.filterTerm);
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
    "filterTerm"
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
    return this._filterThemes(results, this.filterTerm);
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

  _filterThemes(themes, term) {
    term = term?.trim()?.toLowerCase();
    if (!term) {
      return themes;
    }
    return themes.filter(({ name }) => name.toLowerCase().includes(term));
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
      this.set("currentTab", newTab);
      if (!this.showFilter) {
        this.set("filterTerm", null);
      }
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
