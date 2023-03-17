import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class LazyVideo extends Component {
  @tracked isLoaded = false;

  @action
  loadEmbed() {
    if (!this.isLoaded) {
      this.isLoaded = true;
      this.args.callback?.();
    }
  }

  @action
  onKeyPress(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.loadEmbed();
    }
  }
}
