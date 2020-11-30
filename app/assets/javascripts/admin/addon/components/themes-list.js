import { COMPONENTS, THEMES } from "admin/models/theme";
import { equal, gt } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Component.extend({
  router: service(),
  THEMES,
  COMPONENTS,

  classNames: ["themes-list"],

  hasThemes: gt("themesList.length", 0),
  hasActiveThemes: gt("activeThemes.length", 0),
  hasInactiveThemes: gt("inactiveThemes.length", 0),

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
    "themesList.@each.default"
  )
  inactiveThemes(themes) {
    if (this.componentsTabActive) {
      return themes.filter((theme) => theme.get("parent_themes.length") <= 0);
    }
    return themes.filter(
      (theme) => !theme.get("user_selectable") && !theme.get("default")
    );
  },

  @discourseComputed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default"
  )
  activeThemes(themes) {
    if (this.componentsTabActive) {
      return themes.filter((theme) => theme.get("parent_themes.length") > 0);
    } else {
      return themes
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
  },

  actions: {
    changeView(newTab) {
      if (newTab !== this.currentTab) {
        this.set("currentTab", newTab);
      }
    },
    navigateToTheme(theme) {
      this.router.transitionTo("adminCustomizeThemes.show", theme);
    },
  },
});
