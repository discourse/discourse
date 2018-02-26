import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  attributeBindings: [
    "tabindex",
    "ariaLabel:aria-label",
    "title",
    "name:data-name",
    "value:data-value",
    "guid:data-guid"
  ],
  classNames: ["selected-name", "choice"],
  classNameBindings: ["isHighlighted", "isLocked"],
  layoutName: "select-kit/templates/components/multi-select/selected-name",
  tagName: "span",
  tabindex: -1,

  @computed("computedContent")
  guid(computedContent) { return Ember.guidFor(computedContent); },

  ariaLabel: Ember.computed.or("computedContent.ariaLabel", "title"),

  @computed("computedContent.title", "name")
  title(computedContentTitle, name) {
    if (computedContentTitle) return computedContentTitle;
    if (name) return name;

    return null;
  },

  didInsertElement() {
    this._super();

    $(this.element).on("backspace.selected-name", () => {
      this._handleBackspace();
    });
  },

  willDestroyElement() {
    this._super();

    $(this.element).off("backspace.selected-name");
  },

  label: Ember.computed.or("computedContent.label", "title", "name"),

  name: Ember.computed.alias("computedContent.name"),

  value: Ember.computed.alias("computedContent.value"),

  isLocked: Ember.computed("computedContent.locked", function() {
    return this.getWithDefault("computedContent.locked", false);
  }),

  click() {
    if (this.get("isLocked") === true) return false;
    this.sendAction("deselect", [this.get("computedContent")]);
    return false;
  },

  _handleBackspace() {
    if (this.get("isLocked") === true) return false;

    if (this.get("isHighlighted")) {
      this.sendAction("deselect", [this.get("computedContent")]);
    } else {
      this.set("isHighlighted", true);
    }
  }
});
