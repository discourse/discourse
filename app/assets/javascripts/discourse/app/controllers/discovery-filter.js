import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class extends Controller {
  @tracked status = "";

  queryParams = ["status"];

  get queryString() {
    let paramStrings = [];

    this.queryParams.forEach((key) => {
      if (this[key]) {
        paramStrings.push(`${key}:${this[key]}`);
      }
    });

    return paramStrings.join(" ");
  }

  @action
  updateTopicsListQueryParams(queryString) {
    for (const match of queryString.matchAll(/(\w+):([^:\s]+)/g)) {
      const key = match[1];
      const value = match[2];

      if (this.queryParams.includes(key)) {
        this.set(key, value);
      }
    }
  }
}
