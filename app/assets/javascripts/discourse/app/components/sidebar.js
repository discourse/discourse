import GlimmerComponent from "discourse/components/glimmer";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class Sidebar extends GlimmerComponent {
  @tracked shouldDisplay = true;

  @action
  hide() {
    this.shouldDisplay = false;
  }

  @action
  show() {
    this.shouldDisplay = true;
  }
}
