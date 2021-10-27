import { and, gt } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { escape } from "pretty-text/sanitizer";
import { iconHTML } from "discourse-common/lib/icon-library";

const MAX_COMPONENTS = 4;

export default Component.extend({
  childrenExpanded: false,
  classNames: ["themes-list-item"],
  classNameBindings: ["theme.selected:selected"],
  hasComponents: gt("children.length", 0),
  displayComponents: and("hasComponents", "theme.isActive"),
  displayHasMore: gt("theme.childThemes.length", MAX_COMPONENTS),

  click(e) {
    if (!$(e.target).hasClass("others-count")) {
      this.navigateToTheme();
    }
  },

  @discourseComputed(
    "theme.component",
    "theme.childThemes.@each.name",
    "theme.childThemes.length",
    "childrenExpanded"
  )
  children() {
    const theme = this.theme;
    let children = theme.get("childThemes");
    if (theme.get("component") || !children) {
      return [];
    }
    children = this.childrenExpanded
      ? children
      : children.slice(0, MAX_COMPONENTS);
    return children.map((t) => {
      const name = escape(t.name);
      return t.enabled ? name : `${iconHTML("ban")} ${name}`;
    });
  },

  @discourseComputed("children")
  childrenString(children) {
    return children.join(", ");
  },

  @discourseComputed(
    "theme.childThemes.length",
    "theme.component",
    "childrenExpanded",
    "children.length"
  )
  moreCount(childrenCount, component, expanded) {
    if (component || !childrenCount || expanded) {
      return 0;
    }
    return childrenCount - MAX_COMPONENTS;
  },

  actions: {
    toggleChildrenExpanded() {
      this.toggleProperty("childrenExpanded");
    },
  },
});
