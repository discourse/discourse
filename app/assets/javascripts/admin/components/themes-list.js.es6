import { THEMES, COMPONENTS } from "admin/models/theme";
import { default as computed } from "ember-addons/ember-computed-decorators";

const NUM_ENTRIES = 8;

export default Ember.Component.extend({
  THEMES: THEMES,
  COMPONENTS: COMPONENTS,

  classNames: ["themes-list"],

  hasThemes: Em.computed.gt("themesList.length", 0),
  hasUserThemes: Em.computed.gt("userThemes.length", 0),
  hasInactiveThemes: Em.computed.gt("inactiveThemes.length", 0),

  themesTabActive: Em.computed.equal("currentTab", THEMES),
  componentsTabActive: Em.computed.equal("currentTab", COMPONENTS),

  @computed("themes", "components", "currentTab")
  themesList(themes, components) {
    if (this.get("themesTabActive")) {
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
    if (this.get("componentsTabActive")) {
      return [];
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
  userThemes(themes) {
    if (this.get("componentsTabActive")) {
      return [];
    }
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
  },

  didRender() {
    let height = -1;
    this.$(".themes-list-item")
      .slice(0, NUM_ENTRIES)
      .each(function() {
        height += $(this).outerHeight();
      });
    if (height >= 485 && height <= 800) {
      this.$(".themes-list-container").css("max-height", `${height}px`);
    }
  },

  actions: {
    changeView(newTab) {
      if (newTab !== this.get("currentTab")) {
        this.set("currentTab", newTab);
      }
    }
  }
});
