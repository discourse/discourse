import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class AdminPostMenuButtons extends Service {
  @tracked callbacks = [];

  addButton(callback) {
    this.callbacks.push(callback);
  }
}
