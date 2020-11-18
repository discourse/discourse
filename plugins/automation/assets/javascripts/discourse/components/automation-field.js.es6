import Component from "@ember/component";

export default Component.extend({
  placeholdersString: Ember.computed("field.placeholders", function() {
    return this.field.placeholders.join(", ");
  })
});
