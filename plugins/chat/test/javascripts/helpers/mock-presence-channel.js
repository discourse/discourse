import EmberObject from "@ember/object";

export default class MockPresenceChannel extends EmberObject {
  users = [];
  name = null;
  subscribed = false;

  async unsubscribe() {
    this.set("subscribed", false);
  }

  async subscribe() {
    this.set("subscribed", true);
  }
}
