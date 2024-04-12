import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import Modifier from "ember-modifier";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";

const CSS_TRANSITION_DELAY_MS = 300;
const TRANSITION_CLASS = "-fade-out";

class AutoCloseToast extends Modifier {
  element;
  close;
  duration;
  transitionLaterHandler;
  closeLaterHandler;
  progressBar;
  progressAnimation;

  constructor(owner, args) {
    super(owner, args);

    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, _, { close, duration, progressBar }) {
    this.element = element;
    this.close = close;
    this.duration = duration;
    this.timeRemaining = duration;
    this.progressBar = progressBar;
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
    this.stopTimer();
    this.element.removeEventListener("mouseenter", this.stopTimer);
    this.element.removeEventListener("mouseleave", this.startTimer);
    this.progressBar = null;
  }
}

export default class DToast extends Component {
  @tracked progressBar;

  @action
  registerProgressBar(element) {
    this.progressBar = element;
  }

  <template>
    <output
      role={{if @toast.options.autoClose "status" "log"}}
      key={{@toast.id}}
      class={{concatClass "fk-d-toast" @toast.options.class}}
      {{(if
        @toast.options.autoClose
        (modifier
          AutoCloseToast
          close=@toast.close
          duration=@toast.options.duration
          progressBar=this.progressBar
        )
      )}}
    >
      <@toast.options.component
        @data={{@toast.options.data}}
        @close={{@toast.close}}
        @showProgressBar={{and
          @toast.options.showProgressBar
          @toast.options.autoClose
        }}
        @onRegisterProgressBar={{this.registerProgressBar}}
      />
    </output>
  </template>
}
