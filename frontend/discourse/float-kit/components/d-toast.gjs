import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import concatClass from "discourse/helpers/concat-class";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import DSheet from "./d-sheet";
import DSheetSpecialWrapperContent from "./d-sheet/special-wrapper/content";
import DSheetSpecialWrapperRoot from "./d-sheet/special-wrapper/root";

export default class DToast extends Component {
  @service capabilities;

  @tracked pointerOver = false;
  @tracked travelStatus = "idleOutside";
  @tracked presented = true;

  autoCloseTimeout = null;
  contentPlacement = "start";
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

  get tracks() {
    return this.largeViewport.matches || this.capabilities.isAndroid
      ? "right"
      : "top";
  }

  get autoCloseDelay() {
    return this.args.autoCloseDelay ?? 5000;
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
  }

  get toastsContainers() {
    return document.querySelector(".fk-d-toasts");
  }

  <template>
    <DSheet.Root
      @presented={{this.presented}}
      @onPresentedChange={{this.handlePresentedChange}}
      @role=""
      as |sheet|
    >
      <DSheet.Portal @sheet={{sheet}} @container={{this.toastsContainers}}>
        <div role="status" aria-live="polite">
          <DSheet.View
            @sheet={{sheet}}
            @contentPlacement="start"
            @tracks={{this.tracks}}
            @inertOutside={{false}}
            @onClickOutside={{hash dismiss=false stopOverlayPropagation=false}}
            class={{concatClass
              "d-toast"
              (if this.tracks (concat "d-toast-" this.tracks))
            }}
          >
            <DSheet.Content @sheet={{sheet}} class="d-toast-content">
              <DSheetSpecialWrapperRoot @sheet={{sheet}}>
                <DSheetSpecialWrapperContent
                  class="d-toast-inner-content"
                  {{on "pointerenter" this.handlePointerEnter}}
                  {{on "pointerleave" this.handlePointerLeave}}
                >
                  {{#if @showProgressBar}}
                    <div
                      class="fk-d-default-toast__progress-bar"
                      {{didInsert this.registerProgressBar}}
                    ></div>
                  {{/if}}
                  <DDefaultToast @data={{@toast.options.data}} />
                </DSheetSpecialWrapperContent>
              </DSheetSpecialWrapperRoot>
            </DSheet.Content>
          </DSheet.View>
        </div>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}
