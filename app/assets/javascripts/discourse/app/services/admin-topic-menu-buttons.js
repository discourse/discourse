import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class AdminTopicMenuButtons extends Service {
  @tracked callbacks = [];

  addButton(callback) {
    this.callbacks.push(callback);
  }
}
