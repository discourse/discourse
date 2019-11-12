import { alias, none, or } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

const { isEmpty, makeArray } = Ember;

export default Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header"],
  classNameBindings: ["isFocused", "isNone"],
  attributeBindings: [
    "tabindex",
    "ariaLabel:aria-label",
    "ariaHasPopup:aria-haspopup",
    "sanitizedTitle:title",
    "value:data-value",
    "name:data-name"
  ],

  forceEscape: alias("options.forceEscape"),

  isNone: none("computedContent.value"),

  ariaHasPopup: "true",

  ariaLabel: or("computedContent.ariaLabel", "sanitizedTitle"),

  @discourseComputed("computedContent.title", "name")
  title(computedContentTitle, name) {
    if (computedContentTitle) return computedContentTitle;
    if (name) return name;

    return "";
  },

  // this might need a more advanced solution
  // but atm it's the only case we have to handle
  @discourseComputed("title")
  sanitizedTitle(title) {
    return String(title).replace("&hellip;", "");
  },

  label: or("computedContent.label", "title", "name"),

  name: alias("computedContent.name"),

  value: alias("computedContent.value"),

  @discourseComputed("computedContent.icon", "computedContent.icons")
  icons(icon, icons) {
    return makeArray(icon)
      .concat(icons)
      .filter(i => !isEmpty(i));
  },

  click() {
    this.onToggle();
  }
});
