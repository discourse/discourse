import EmberObject from "@ember/object";

export default class UserActionGroup extends EmberObject {
  push(item) {
    if (!this.items) {
      this.items = [];
    }
    return this.items.push(item);
  }
}
