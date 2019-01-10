import { THEMES, COMPONENTS } from "admin/models/theme";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  THEMES: THEMES,
  COMPONENTS: COMPONENTS,

  classNames: ["themes-list"],

  hasThemes: Ember.computed.gt("themesList.length", 0),
  hasUserThemes: Ember.computed.gt("userThemes.length", 0),
  hasInactiveThemes: Ember.computed.gt("inactiveThemes.length", 0),

  themesTabActive: Ember.computed.equal("currentTab", THEMES),
  componentsTabActive: Ember.computed.equal("currentTab", COMPONENTS),

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
    this._super(...arguments);

    // hide scrollbar
    const $container = this.$(".themes-list-container");
    const containerNode = $container[0];
    if (containerNode) {
      const width = containerNode.offsetWidth - containerNode.clientWidth;
      $container.css("width", `calc(100% + ${width}px)`);
    }
  },

  actions: {
    changeView(newTab) {
      if (newTab !== this.get("currentTab")) {
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
