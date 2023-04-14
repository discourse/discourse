import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class extends Controller {
  @tracked tagsForUser = null;
  @tracked sortedByCount = true;
  @tracked sortedByName = false;
  @tracked sortProperties = ["count:desc", "id"];

  @action
  sortByCount(event) {
    event?.preventDefault();

    this.sortProperties = ["count:desc", "id"];
    this.sortedByCount = true;
    this.sortedByName = false;
  }

  @action
  sortById(event) {
    event?.preventDefault();

    this.sortProperties = ["id"];
    this.sortedByCount = false;
    this.sortedByName = true;
  }
}
