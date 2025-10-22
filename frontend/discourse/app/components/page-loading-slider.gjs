import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { run } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";

export default class PageLoadingSlider extends Component {
  @service loadingSlider;
  @service capabilities;

  @tracked state = "ready";

  constructor() {
    super(...arguments);
    this.loadingSlider.on("stateChanged", this.stateChanged);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.loadingSlider.off("stateChange", this, "stateChange");
    if (this._deferredStateChange) {
      cancelAnimationFrame(this._deferredStateChange);
      this._deferredStateChange = null;
    }
  }

  @bind
  stateChanged(loading) {
    if (this._deferredStateChange) {
      cancelAnimationFrame(this._deferredStateChange);
      this._deferredStateChange = null;
    }

    if (loading && this.ready) {
      this.state = "loading";
    } else if (loading) {
      this.state = "ready";
      this._deferredStateChange = requestAnimationFrame(() => {
        run(() => (this.state = "loading"));
      });
    } else {
      this.state = "done";
    }
  }

  get containerStyle() {
    const duration = this.loadingSlider.averageLoadingDuration.toFixed(2);
    return htmlSafe(`--loading-duration: ${duration}s`);
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

  <template>
    {{#if (eq this.loadingSlider.mode "slider")}}
      <div
        {{on "transitionend" this.onContainerTransitionEnd}}
        style={{this.containerStyle}}
        class={{concatClass
          "loading-indicator-container"
          this.state
          (if this.capabilities.isAppWebview "discourse-hub-webview")
        }}
      >
        <div
          {{on "transitionend" this.onBarTransitionEnd}}
          class="loading-indicator"
        >
        </div>
      </div>
    {{/if}}
  </template>
}
