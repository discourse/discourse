import Service from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class AdminPostMenuButtons extends Service {
  @tracked callbacks = [];

  addButton(callback) {
    this.callbacks.push(callback);
  }
}
