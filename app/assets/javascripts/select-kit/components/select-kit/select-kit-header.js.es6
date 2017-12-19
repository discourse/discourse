import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-header",
  classNames: ["select-kit-header", "select-box-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "tabindex",
    "label:aria-label",
    "ariaHasPopup:aria-haspopup",
    "label:title",
    "value:data-value"
  ],

  ariaHasPopup: true,

  name: Ember.computed.alias("computedContent.name"),

  value: Ember.computed.alias("computedContent.value"),

  @computed("computedContent.icon", "computedContent.icons")
  icons(icon, icons) {
    return Ember.makeArray(icon).concat(icons).filter(i => !Ember.isEmpty(i));
  },

  @computed("title", "computedContent.title", "name")
  label(title, computedContentTitle, name) {
    if (title) return I18n.t(title).htmlSafe();
    if (computedContentTitle) return computedContentTitle.htmlSafe();
    if (name) return name;

    return null;
  },

  click() {
    this.sendAction("onToggle");
  }
});
