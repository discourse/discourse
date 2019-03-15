import computed from "ember-addons/ember-computed-decorators";
const { isEmpty, makeArray } = Ember;

export default Ember.Component.extend({
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

  forceEscape: Ember.computed.alias("options.forceEscape"),

  isNone: Ember.computed.none("computedContent.value"),

  ariaHasPopup: true,

  ariaLabel: Ember.computed.or("computedContent.ariaLabel", "sanitizedTitle"),

  @computed("computedContent.title", "name")
  title(computedContentTitle, name) {
    if (computedContentTitle) return computedContentTitle;
    if (name) return name;

    return "";
  },

  // this might need a more advanced solution
  // but atm it's the only case we have to handle
  @computed("title")
  sanitizedTitle(title) {
    return String(title).replace("&hellip;", "");
  },

  label: Ember.computed.or("computedContent.label", "title", "name"),

  name: Ember.computed.alias("computedContent.name"),

  value: Ember.computed.alias("computedContent.value"),

  @computed("computedContent.icon", "computedContent.icons")
  icons(icon, icons) {
    return makeArray(icon)
      .concat(icons)
      .filter(i => !isEmpty(i));
  },

  click() {
    this.onToggle();
  }
});
