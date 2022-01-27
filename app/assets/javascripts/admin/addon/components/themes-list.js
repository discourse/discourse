import { COMPONENTS, THEMES } from "admin/models/theme";
import { equal, gt, gte } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default Component.extend({
  router: service(),
  THEMES,
  COMPONENTS,

  classNames: ["themes-list"],
  filterTerm: null,

  hasThemes: gt("themesList.length", 0),
  hasActiveThemes: gt("activeThemes.length", 0),
  hasInactiveThemes: gt("inactiveThemes.length", 0),
  showFilter: gte("themesList.length", 10),

  themesTabActive: equal("currentTab", THEMES),
  componentsTabActive: equal("currentTab", COMPONENTS),

  @discourseComputed("themes", "components", "currentTab")
  themesList(themes, components) {
    if (this.themesTabActive) {
      return themes;
    } else {
      return components;
    }
  },

  @discourseComputed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default",
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
  },

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
  },

  _filterThemes(themes, term) {
    term = term?.trim()?.toLowerCase();
    if (!term) {
      return themes;
    }
    return themes.filter(({ name }) => name.toLowerCase().includes(term));
  },

  @action
  changeView(newTab) {
    if (newTab !== this.currentTab) {
      this.set("currentTab", newTab);
      if (!this.showFilter) {
        this.set("filterTerm", null);
      }
    }
  },

  @action
  navigateToTheme(theme) {
    this.router.transitionTo("adminCustomizeThemes.show", theme);
  },
});
