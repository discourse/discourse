import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("field.value")
  showStaffCount: staffCount => staffCount > 1
});
