import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "tabindex",
    "ariaLabel:aria-label",
    "ariaHasPopup:aria-haspopup",
    "title",
    "value:data-value",
    "name:data-name",
  ],

  ariaHasPopup: true,

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

  @computed("computedContent.icon", "computedContent.icons")
  icons(icon, icons) {
    return Ember.makeArray(icon).concat(icons).filter(i => !Ember.isEmpty(i));
  },

  click() {
    this.sendAction("toggle");
  }
});
