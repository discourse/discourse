import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";

export default class LazyVideo extends Component {
  @tracked isLoaded = false;

  @action
  loadEmbed() {
    if (!this.isLoaded) {
      this.isLoaded = true;
      this.args.onLoadedVideo?.();
    }
  }

  @action
  onKeyPress(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.loadEmbed();
    }
  }

  get thumbnailStyle() {
    const color = this.args.videoAttributes.dominantColor;
    if (color?.match(/^[0-9A-Fa-f]+$/)) {
      return htmlSafe(`background-color: #${color};`);
    }
  }
}
