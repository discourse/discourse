import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import concatClass from "discourse/helpers/concat-class";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import { eq } from "discourse/truth-helpers";
import DSheet from "./d-sheet";

export default class DToast extends Component {
  @service capabilities;

  @tracked pointerOver = false;
  @tracked travelStatus = "idleOutside";
  @tracked presented = true;

  autoCloseTimeout = null;
  largeViewport = new TrackedMediaQuery("(min-width: 1000px)");
  progressBar = null;
  progressAnimation = null;
  timeRemaining = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.cancelAutoCloseTimeout();
    this.largeViewport.teardown();
    this.progressBar = null;
  }

  get contentPlacement() {
    return "top";
  }

  get autoCloseDelay() {
    return this.args.autoCloseDelay ?? 55000;
  }

  @action
  handleTravelStatusChange(status) {
    this.travelStatus = status;

    if (status === "idleOutside") {
      this.pointerOver = false;
      this.cancelAutoCloseTimeout();
    }

    if (
      status === "idleInside" &&
      !this.pointerOver &&
      this.args.sheet?.isPresented
    ) {
      this.startAutoCloseTimeout();
    } else {
      this.cancelAutoCloseTimeout();
    }

    this.args.onTravelStatusChange?.(status);
  }

  @action
  registerProgressBar(element) {
    this.progressBar = element;
    this.startAutoCloseTimeout();
  }

  startProgressAnimation() {
    if (!this.progressBar) {
      return;
    }

    if (this.progressAnimation) {
      this.progressAnimation.play();
      this.progressBar.style.opacity = 1;
      return;
    }

    this.progressAnimation = this.progressBar.animate(
      { transform: "scaleX(0)" },
      { duration: this.autoCloseDelay, fill: "forwards" }
    );
  }

  pauseProgressAnimation() {
    if (
      !this.progressAnimation ||
      this.progressAnimation.currentTime === this.autoCloseDelay
    ) {
      return;
    }

    this.progressAnimation.pause();
    this.progressBar.style.opacity = 0.5;
    this.timeRemaining =
      this.autoCloseDelay - this.progressAnimation.currentTime;
  }

  @action
  handlePointerEnter() {
    this.pointerOver = true;
    this.pauseProgressAnimation();
    this.cancelAutoCloseTimeout();
  }

  @action
  handlePointerLeave() {
    this.pointerOver = false;
    this.startAutoCloseTimeout();
  }

  startAutoCloseTimeout() {
    this.cancelAutoCloseTimeout();
    this.startProgressAnimation();
    this.autoCloseTimeout = later(() => {
      this.presented = false;
    }, this.timeRemaining ?? this.autoCloseDelay);
  }

  cancelAutoCloseTimeout() {
    if (this.autoCloseTimeout) {
      cancel(this.autoCloseTimeout);
      this.autoCloseTimeout = null;
    }
  }

  @action
  handlePresentedChange(presented) {
    this.presented = presented;

    if (!presented) {
      this.args.toast.dismissed = true;
    }
  }

  @action
  handleClosed() {
    this.args.toast.close();
  }

  get toastsContainers() {
    return document.querySelector(".fk-d-toasts");
  }

  get toastStyles() {
    const styles = [
      `--index: ${this.args.index}`,
      `--toasts-before: ${this.args.index}`,
      `--z-index: ${this.args.index}`,
    ];

    return htmlSafe(styles.join("; "));
  }

  get isFront() {
    if (this.args.toast.dismissed) {
      return false;
    }

    const activeToasts = this.args.toasts.filter((t) => !t.dismissed);
    return this.args.toast === activeToasts[activeToasts.length - 1];
  }

  get innerStyles() {
    const activeToasts = this.args.toasts.filter((t) => !t.dismissed);
    const indexInActive = activeToasts.indexOf(this.args.toast);

    const distanceFromFront =
      indexInActive === -1 ? 0 : activeToasts.length - 1 - indexInActive;

    const styles = [`--distance-from-front: ${distanceFromFront}`];
    return htmlSafe(styles.join("; "));
  }

  <template>
    <DSheet.Root
      @presented={{this.presented}}
      @onPresentedChange={{this.handlePresentedChange}}
      @onClosed={{this.handleClosed}}
      @role=""
      as |sheet|
    >
      <DSheet.Portal @sheet={{sheet}} @container={{this.toastsContainers}}>
        <div role="status" aria-live="polite">
          <DSheet.View
            @sheet={{sheet}}
            @contentPlacement={{this.contentPlacement}}
            @inertOutside={{false}}
            @onClickOutside={{hash dismiss=false stopOverlayPropagation=false}}
            class={{concatClass
              "d-toast"
              (concat "d-toast-" this.contentPlacement)
            }}
            style={{this.toastStyles}}
          >
            <DSheet.Content
              @sheet={{sheet}}
              @asChild={{true}}
              as |contentAttrs|
            >
              <DSheet.SpecialWrapper.Root
                @sheet={{sheet}}
                @contentAttrs={{contentAttrs}}
                class="d-toast-content"
              >
                <DSheet.SpecialWrapper.Content
                  class="d-toast-inner-content"
                  data-index={{@index}}
                  data-front={{if this.isFront "true" "false"}}
                  data-presented={{if this.presented "true" "false"}}
                  style={{this.innerStyles}}
                  {{on "pointerenter" this.handlePointerEnter}}
                  {{on "pointerleave" this.handlePointerLeave}}
                >
                  {{#if @showProgressBar}}
                    <div
                      class="fk-d-default-toast__progress-bar"
                      {{didInsert this.registerProgressBar}}
                    ></div>
                  {{/if}}

                  <DDefaultToast
                    @data={{@toast.options.data}}
                    @sheet={{sheet}}
                    @isFront={{this.isFront}}
                  />
                </DSheet.SpecialWrapper.Content>
              </DSheet.SpecialWrapper.Root>
            </DSheet.Content>
          </DSheet.View>
        </div>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}
