import { gt, alias } from "@ember/object/computed";
import Component from "@ember/component";
export default Component.extend({
  tagName: "",

  multiple: gt("bundle.actions.length", 1),
  first: alias("bundle.actions.firstObject"),

  actions: {
    performById(id) {
      this.attrs.performAction(this.get("bundle.actions").findBy("id", id));
    },

    perform(action) {
      this.attrs.performAction(action);
    }
  }
});
