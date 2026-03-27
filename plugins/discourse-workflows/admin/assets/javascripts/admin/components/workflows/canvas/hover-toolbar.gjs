import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, later } from "@ember/runloop";

const DEFAULT_HIDE_DELAY = 500;

export default class CanvasHoverToolbar extends Component {
  @tracked isVisible = false;
  #hideTimer = null;
  #hoverTarget = null;

  get hideDelay() {
    return this.args.hideDelay ?? DEFAULT_HIDE_DELAY;
  }

  @action
  setup(element) {
    this.#hoverTarget = this.args.hoverSelector
      ? element.closest(this.args.hoverSelector)
      : element.parentElement;

    this.#hoverTarget?.addEventListener("mouseenter", this.show);
    this.#hoverTarget?.addEventListener("mouseleave", this.scheduleHide);
  }

  @action
  teardown() {
    cancel(this.#hideTimer);
    this.#hoverTarget?.removeEventListener("mouseenter", this.show);
    this.#hoverTarget?.removeEventListener("mouseleave", this.scheduleHide);
  }

  @action
  show() {
    cancel(this.#hideTimer);
    this.isVisible = true;
  }

  @action
  scheduleHide() {
    cancel(this.#hideTimer);
    this.#hideTimer = later(() => {
      this.isVisible = false;
    }, this.hideDelay);
  }

  <template>
    <div
      class="workflow-canvas-toolbar {{if this.isVisible '--visible'}}"
      {{didInsert this.setup}}
      {{willDestroy this.teardown}}
      {{on "mouseenter" this.show}}
      {{on "mouseleave" this.scheduleHide}}
    >
      {{yield}}
    </div>
  </template>
}
