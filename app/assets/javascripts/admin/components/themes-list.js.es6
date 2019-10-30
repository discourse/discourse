import { gt, equal } from "@ember/object/computed";
import Component from "@ember/component";
import { THEMES, COMPONENTS } from "admin/models/theme";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  THEMES: THEMES,
  COMPONENTS: COMPONENTS,

  classNames: ["themes-list"],

  hasThemes: gt("themesList.length", 0),
  hasActiveThemes: gt("activeThemes.length", 0),
  hasInactiveThemes: gt("inactiveThemes.length", 0),

  themesTabActive: equal("currentTab", THEMES),
  componentsTabActive: equal("currentTab", COMPONENTS),

  @computed("themes", "components", "currentTab")
  themesList(themes, components) {
    if (this.themesTabActive) {
      return themes;
    } else {
      return components;
    }
  },

  @computed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default"
  )
  inactiveThemes(themes) {
    if (this.componentsTabActive) {
      return themes.filter(theme => theme.get("parent_themes.length") <= 0);
    }
    return themes.filter(
      theme => !theme.get("user_selectable") && !theme.get("default")
    );
  },

  @computed(
    "themesList",
    "currentTab",
    "themesList.@each.user_selectable",
    "themesList.@each.default"
  )
  activeThemes(themes) {
    if (this.componentsTabActive) {
      return themes.filter(theme => theme.get("parent_themes.length") > 0);
    } else {
      themes = themes.filter(
        theme => theme.get("user_selectable") || theme.get("default")
      );
      return _.sortBy(themes, t => {
        return [
          !t.get("default"),
          !t.get("user_selectable"),
          t.get("name").toLowerCase()
        ];
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
      Ember.getOwner(this)
        .lookup("router:main")
        .transitionTo("adminCustomizeThemes.show", theme);
    }
  }
});
