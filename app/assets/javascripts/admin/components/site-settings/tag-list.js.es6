import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("value")
  selectedTags: {
    get(value) {
      return value.split("|");
    },
    set(value) {
      this.set("value", value.join("|"));
      return value;
    }
  }
});
