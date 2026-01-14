import { registerDestructor } from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";

const CSS_TRANSITION_DELAY_MS = 300;
const TRANSITION_CLASS = "-fade-out";

export default class AutoCloseToast extends Modifier {
  element;
  close;
  duration;
  transitionLaterHandler;
  closeLaterHandler;
  progressBar;
  progressAnimation;
  enabled;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, _, { close, duration, progressBar, enabled }) {
    if (enabled === false) {
      this.enabled = false;
      return;
    }

    this.element = element;
    this.close = close;
    this.duration = duration;
    this.timeRemaining = duration;
    this.progressBar = progressBar;
    this.element.addEventListener("touchstart", this.stopTimer, {
      passive: true,
      once: true,
    });
    this.element.addEventListener("mouseenter", this.stopTimer, {
      passive: true,
    });
    this.element.addEventListener("mouseleave", this.startTimer, {
      passive: true,
    });
    this.startTimer();
  }

  @bind
  startTimer() {
    this.startProgressAnimation();

    this.transitionLaterHandler = discourseLater(() => {
      this.element.classList.add(TRANSITION_CLASS);

      this.closeLaterHandler = discourseLater(() => {
        this.close();
      }, CSS_TRANSITION_DELAY_MS);
    }, this.timeRemaining);
  }

  @bind
  stopTimer() {
    this.pauseProgressAnimation();
    cancel(this.transitionLaterHandler);
    cancel(this.closeLaterHandler);
  }

  @bind
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
      { transform: `scaleX(0)` },
      { duration: this.duration, fill: "forwards" }
    );
  }

  @bind
  pauseProgressAnimation() {
    if (
      !this.progressAnimation ||
      this.progressAnimation.currentTime === this.duration
    ) {
      return;
    }

    this.progressAnimation.pause();
    this.progressBar.style.opacity = 0.5;
    this.timeRemaining = this.duration - this.progressAnimation.currentTime;
  }

  cleanup() {
    if (!this.enabled) {
      return;
    }

    this.stopTimer();
    this.element.removeEventListener("mouseenter", this.stopTimer);
    this.element.removeEventListener("mouseleave", this.startTimer);
    this.progressBar = null;
  }
}
