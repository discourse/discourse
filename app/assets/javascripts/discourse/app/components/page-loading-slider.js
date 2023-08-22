import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { cancel, next } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default class extends Component {
  @service loadingSlider;
  @service capabilities;

  @tracked state = "ready";

  constructor() {
    super(...arguments);
    this.loadingSlider.on("stateChanged", this.stateChanged);
  }

  @bind
  stateChanged(loading) {
    if (this._deferredStateChange) {
      cancel(this._deferredStateChange);
      this._deferredStateChange = null;
    }

    if (loading && this.ready) {
      this.state = "loading";
    } else if (loading) {
      this.state = "ready";
      this._deferredStateChange = next(() => (this.state = "loading"));
    } else {
      this.state = "done";
    }
  }

  destroy() {
    this.loadingSlider.off("stateChange", this, "stateChange");
    super.destroy();
  }

  @action
  onContainerTransitionEnd(event) {
    if (
      event.target === event.currentTarget &&
      event.propertyName === "opacity"
    ) {
      this.state = "ready";
    }
  }

  @action
  onBarTransitionEnd(event) {
    if (
      event.target === event.currentTarget &&
      event.propertyName === "transform" &&
      this.state === "loading"
    ) {
      this.state = "still-loading";
    }
  }

  get containerStyle() {
    const duration = this.loadingSlider.averageLoadingDuration.toFixed(2);
    return htmlSafe(`--loading-duration: ${duration}s`);
  }
}
