import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "span",

  @computed("group.full_name", "group.title")
  showFullName(fullName, title) {
    return fullName && fullName.length && fullName !== title;
  }
});
