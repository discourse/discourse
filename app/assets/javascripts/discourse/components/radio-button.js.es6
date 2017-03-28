import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName : "input",
  type : "radio",
  attributeBindings : ["name", "type", "value", "checked:checked", "disabled:disabled"],

  click: function() {
    this.set("selection", this.$().val());
  },

  @computed('value', 'selection')
  checked(value, selection) {
    return value === selection;
  },
});
