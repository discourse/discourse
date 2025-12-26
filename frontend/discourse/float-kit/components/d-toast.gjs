import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import deprecated from "discourse/lib/deprecated";
import { or } from "discourse/truth-helpers";
import DSheet from "./d-sheet";

export default class DToast extends Component {
  @service capabilities;

  @tracked pointerOver = false;
  @tracked travelStatus = "idleOutside";
  @tracked presented = true;
  @tracked progressBar = null;

  autoCloseTimeout = null;
  progressAnimation = null;
  timeRemaining = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.cancelAutoCloseTimeout();
    this.progressBar = null;
  }

  get contentPlacement() {
    return "top";
  }

  get tracks() {
    return this.capabilities.isAndroid ? "right" : "top";
  }

  get duration() {
    const duration = this.args.toast.options.duration;

    if (duration === "long") {
      return 5000;
    } else if (duration === "short") {
      return 3000;
    } else {
      deprecated(
        "Using an integer for the duration property of the d-toast component is deprecated. Use `short` or `long` instead.",
        { id: "float-kit.d-toast.duration" }
      );

      return duration;
    }
  }

  @action
  handleTravelStatusChange(status) {
    this.travelStatus = status;

    if (status === "idleOutside") {
      this.pointerOver = false;
    }

    this.args.onTravelStatusChange?.(status);
  }

  @action
  registerProgressBar(element) {
    this.progressBar = element;
  }

  @action
  syncAutoClose() {
    if (this.travelStatus !== "idleInside" || !this.presented) {
      this.pauseProgressAnimation();
      this.cancelAutoCloseTimeout();
      return;
    }

    if (this.isFront && !this.pointerOver) {
      this.startAutoCloseTimeout();
    } else {
      this.pauseProgressAnimation();
      this.cancelAutoCloseTimeout();
    }
  }

  startProgressAnimation() {
    if (!this.progressBar) {
      return;
    }

    if (this.progressAnimation) {
      this.progressAnimation.play();
      return;
    }

    this.progressAnimation = this.progressBar.animate(
      { transform: "scaleX(0)" },
      { duration: this.duration, fill: "forwards" }
    );
  }

  pauseProgressAnimation() {
    if (
      !this.progressAnimation ||
      this.progressAnimation.currentTime === this.duration
    ) {
      return;
    }

    this.progressAnimation.pause();
    this.timeRemaining = this.duration - this.progressAnimation.currentTime;
  }

  @action
  handlePointerDown(event) {
    if (event.pointerType === "touch") {
      this.pointerOver = true;
    }
  }

  @action
  handlePointerUp(event) {
    if (event.pointerType === "touch") {
      this.pointerOver = false;
    }
  }

  @action
  handlePointerEnter(event) {
    if (event.pointerType === "mouse") {
      this.pointerOver = true;
    }
  }

  @action
  handlePointerLeave(event) {
    if (event.pointerType === "mouse") {
      this.pointerOver = false;
    }
  }

  startAutoCloseTimeout() {
    this.cancelAutoCloseTimeout();
    this.startProgressAnimation();
    this.autoCloseTimeout = later(() => {
      this.presented = false;
    }, this.timeRemaining ?? this.duration);
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
    const order = this.args.toast.stackOrder;
    const styles = [
      `--index: ${order}`,
      `--toasts-before: ${order}`,
      `--z-index: ${order}`,
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

  get enteringAnimationSettings() {
    const activeToasts = this.args.toasts.filter((t) => !t.dismissed);
    const isNewest = this.args.toast === activeToasts[activeToasts.length - 1];

    if (!isNewest) {
      return {
        contentMove: false,
        duration: 400,
      };
    }
    return null;
  }

  <template>
    {{effect
      this.syncAutoClose
      this.isFront
      this.pointerOver
      this.travelStatus
      this.progressBar
    }}

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
            @tracks={{this.tracks}}
            @inertOutside={{false}}
            @onClickOutside={{hash dismiss=false stopOverlayPropagation=false}}
            @onTravelStatusChange={{this.handleTravelStatusChange}}
            @enteringAnimationSettings={{this.enteringAnimationSettings}}
            class={{concatClass
              "d-toast"
              (concat "d-toast-" this.contentPlacement)
              (if
                @toast.options.data?.theme
                (concat "d-toast--" @toast.options.data.theme)
              )
              @toast.options.class
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
                  data-index={{this.args.toast.stackOrder}}
                  data-front={{if this.isFront "true" "false"}}
                  data-presented={{if this.presented "true" "false"}}
                  data-pointer-over={{if this.pointerOver "true" "false"}}
                  data-theme={{or @toast.options.data?.theme "default"}}
                  style={{this.innerStyles}}
                  {{on "pointerenter" this.handlePointerEnter}}
                  {{on "pointerleave" this.handlePointerLeave}}
                  {{on "pointerdown" this.handlePointerDown}}
                  {{on "pointerup" this.handlePointerUp}}
                  {{on "pointercancel" this.handlePointerUp}}
                >
                  <DDefaultToast
                    @data={{@toast.options.data}}
                    @sheet={{sheet}}
                    @isFront={{this.isFront}}
                    @showProgressBar={{@toast.options.showProgressBar}}
                    @registerProgressBar={{this.registerProgressBar}}
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
