import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("user", "category")
  searchParams() {
    return `@${this.get("user.username")} #${this.get("category.slug")}`;
  },
});
