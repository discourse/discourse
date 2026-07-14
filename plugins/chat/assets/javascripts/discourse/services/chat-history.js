import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { deepEqual } from "discourse/lib/object";

export default class ChatHistory extends Service {
  @tracked history;

  get previousRoute() {
    if (this.history?.length > 1) {
      return this.history[this.history.length - 2];
    }
  }

  get currentRoute() {
    if (this.history?.length > 0) {
      return this.history[this.history.length - 1];
    }
  }

  visit(route) {
    if (
      this.currentRoute?.name === route.name &&
      deepEqual(this.currentRoute?.params, route.params)
    ) {
      return;
    }
    this.history = (this.history || []).slice(-9).concat([route]);
  }
}
