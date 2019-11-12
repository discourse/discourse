import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @discourseComputed()
  groupChoices() {
    return this.site.get("groups").map(g => {
      return { name: g.name, id: g.id.toString() };
    });
  }
});
