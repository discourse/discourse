import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header", "select-box-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "dataName:data-name",
    "tabindex",
    "ariaLabel:aria-label",
    "ariaHasPopup:aria-haspopup",
    "title"
  ],

  ariaHasPopup: true,

  ariaLabel: Ember.computed.alias("title"),

  name: Ember.computed.alias("computedContent.name"),

  @computed("computedContent.icon", "computedContent.icons")
  icons(icon, icons) {
    return Ember.makeArray(icon).concat(icons).filter(i => !Ember.isEmpty(i));
  },

  @computed("computedContent.dataName", "name")
  dataName(dataName, name) { return dataName || name; },

  @computed("title", "computedContent.title", "name")
  title(title, computedContentTitle, name) {
    return title || computedContentTitle || name;
  },

  click() {
    this.sendAction("onToggle");
  }
});
