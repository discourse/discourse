// ?
import Component from "@ember/component";

export default Component.extend({
  actions: {
    changed(value) {
      console.log(`value = '${value}'`);
      this.set("field.value", value);
    }
  }
});
