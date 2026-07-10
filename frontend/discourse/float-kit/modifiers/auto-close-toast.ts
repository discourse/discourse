import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";

const CSS_TRANSITION_DELAY_MS = 300;
const TRANSITION_CLASS = "-fade-out";

interface AutoCloseToastSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      close: () => void;
      duration: number;
      progressBar?: HTMLElement | null;
      enabled?: boolean;
    };
  };
}

export default class AutoCloseToast extends Modifier<AutoCloseToastSignature> {
  declare element: HTMLElement;
  declare close: () => void;
  declare duration: number;
  declare timeRemaining: number;
  declare transitionLaterHandler: ReturnType<typeof discourseLater>;
  declare closeLaterHandler: ReturnType<typeof discourseLater>;
  declare progressBar: HTMLElement | null;
  declare progressAnimation: Animation | null;
  declare enabled: boolean;

  constructor(owner: Owner, args: ArgsFor<AutoCloseToastSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(
    element: HTMLElement,
    _: [],
    {
      close,
      duration,
      progressBar,
      enabled,
    }: AutoCloseToastSignature["Args"]["Named"]
  ) {
    if (enabled === false) {
      this.enabled = false;
      return;
    }

    this.element = element;
    this.close = close;
    this.duration = duration;
    this.timeRemaining = duration;
    this.progressBar = progressBar ?? null;
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
      this.progressBar.style.opacity = "1";
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
    // `progressAnimation` only exists once `progressBar` was set, and `cleanup`
    // pauses before clearing it, so the bar is always present here.
    this.progressBar!.style.opacity = "0.5";
    this.timeRemaining =
      this.duration - (this.progressAnimation.currentTime as number);
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
