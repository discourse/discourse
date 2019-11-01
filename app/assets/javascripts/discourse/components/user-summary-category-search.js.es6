import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "",

  @computed("user", "category")
  searchParams() {
    return `@${this.get("user.username")} #${this.get("category.slug")}`;
  }
});
