import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

// Shared by every graph on screen, so one toggle governs every row and total.
export default class ViewFilter {
  @tracked onlyLoaded = true;

  @action
  toggle() {
    this.onlyLoaded = !this.onlyLoaded;
  }
}
