import { default as computed } from "ember-addons/ember-computed-decorators";

const MAX_COMPONENTS = 4;

export default Ember.Component.extend({
  classNames: ["themes-list-item"],
  classNameBindings: ["theme.active:active"],
  hasComponents: Em.computed.gt("children.length", 0),
  hasMore: Em.computed.gt("moreCount", 0),

  @computed(
    "theme.component",
    "theme.childThemes.@each.name",
    "theme.childThemes.length"
  )
  children() {
    const theme = this.get("theme");
    const children = theme.get("childThemes");
    if (theme.get("component") || !children) {
      return [];
    }
    return children.slice(0, MAX_COMPONENTS).map(t => t.get("name"));
  },

  @computed("theme.childThemes.length", "theme.component", "children.length")
  moreCount(childrenCount, component) {
    if (component || !childrenCount) {
      return 0;
    }
    return childrenCount - MAX_COMPONENTS;
  }
});
