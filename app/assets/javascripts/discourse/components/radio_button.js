Discourse.RadioButton = Ember.Component.extend({
  tagName : "input",
  type : "radio",
  attributeBindings : [ "name", "type", "value", "checked:checked" ],
  click : function() {
    this.set("selection", this.$().val());
  },
  checked : function() {
    return this.get("value") === this.get("selection");
  }.property('selection')
});

Em.Handlebars.helper('radio-button', Discourse.RadioButton);
