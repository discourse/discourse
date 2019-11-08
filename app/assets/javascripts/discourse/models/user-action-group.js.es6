import EmberObject from "@ember/object";

export default EmberObject.extend({
  push(item) {
    if (!this.items) {
      this.items = [];
    }
    return this.items.push(item);
  }
});
