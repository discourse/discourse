import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
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
  guid(computedContent) {
    return Ember.guidFor(computedContent);
  },

  ariaLabel: Ember.computed.or("computedContent.ariaLabel", "title"),

  @computed("computedContent.title", "name")
  title(computedContentTitle, name) {
    if (computedContentTitle) return computedContentTitle;
    if (name) return name;

    return null;
  },

  label: Ember.computed.or("computedContent.label", "title", "name"),

  name: Ember.computed.alias("computedContent.name"),

  value: Ember.computed.alias("computedContent.value"),

  isLocked: Ember.computed("computedContent.locked", function() {
    return this.getWithDefault("computedContent.locked", false);
  }),

  @computed("computedContent", "highlightedSelection.[]")
  isHighlighted(computedContent, highlightedSelection) {
    return highlightedSelection.includes(this.computedContent);
  },

  click() {
    if (this.isLocked) return false;
    this.onClickSelectionItem([this.computedContent]);
    return false;
  }
});
