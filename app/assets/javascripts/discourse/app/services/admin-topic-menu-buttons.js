import Service from "@ember/service";

export default class AdminTopicMenuButtons extends Service {
  callbacks = [];

  addButton(callback) {
    this.callbacks.push(callback);
  }
}
