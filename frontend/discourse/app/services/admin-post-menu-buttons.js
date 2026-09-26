import { tracked } from "@glimmer/tracking";
import Service from "discourse/lib/service";

export default class AdminPostMenuButtons extends Service {
  @tracked callbacks = [];

  addButton(callback) {
    this.callbacks.push(callback);
  }
}
