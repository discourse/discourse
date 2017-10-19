import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-header",
  classNames: "select-box-kit-header",
  classNameBindings: ["isFocused"],
  attributeBindings: ["selectedName:data-name"],
  shouldDisplaySelectedName: true,

  @computed("options.shouldDisplaySelectedName")
  shouldDisplaySelectedName(should) {
    if (Ember.isNone(should)) { return true; }
    return should;
  },

  @computed("options.selectedName", "selectedContent.firstObject.name")
  selectedName(optionsSelectedName, firstSelectedContentName) {
    if (Ember.isNone(optionsSelectedName)) {
      return firstSelectedContentName;
    }
    return optionsSelectedName;
  },

  @computed("options.icon")
  icon(optionsIcon) { return optionsIcon; },

  click() { this.sendAction("onToggle"); }
});
