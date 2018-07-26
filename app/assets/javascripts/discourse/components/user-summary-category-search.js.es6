import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("user", "category")
  searchParams() {
    return `@${this.get("user.username")} #${this.get("category.slug")}`;
  }
});
