import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import deprecated from "discourse/lib/deprecated";
import { getMaxAnimationTimeMs } from "discourse/lib/swipe-events";
import swipe from "discourse/modifiers/swipe";
import autoCloseToast from "float-kit/modifiers/auto-close-toast";

const VELOCITY_THRESHOLD = -1.2;

export default class DToast extends Component {
  @service site;

  @tracked progressBar;

  @action
  registerProgressBar(element) {
    this.progressBar = element;
  }

  @action
  async didSwipe(state) {
    if (state.deltaY >= 0) {
      this.#animateWrapperPosition(state.element, 0);
      return;
    }

    if (state.velocityY < VELOCITY_THRESHOLD) {
      await this.#close(state.element);
    } else {
      await this.#animateWrapperPosition(state.element, state.deltaY);
    }
  }

  @action
  async didEndSwipe(state) {
    if (state.velocityY < VELOCITY_THRESHOLD) {
      await this.#close(state.element);
    } else {
      await this.#animateWrapperPosition(state.element, 0);
    }
  }

  async #close(element) {
    await this.#closeWrapperAnimation(element);
    this.args.toast.close();
  }

  async #closeWrapperAnimation(element) {
    await element.animate([{ transform: "translateY(-150px)" }], {
      fill: "forwards",
      duration: getMaxAnimationTimeMs(),
    }).finished;
  }

  async #animateWrapperPosition(element, position) {
    await element.animate([{ transform: `translateY(${position}px)` }], {
      fill: "forwards",
    }).finished;
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

  <template>
    <output
      role={{if @toast.options.autoClose "status" "log"}}
      key={{@toast.id}}
      class={{concatClass "fk-d-toast" @toast.options.class}}
      {{autoCloseToast
        close=@toast.close
        duration=this.duration
        progressBar=this.progressBar
        enabled=@toast.options.autoClose
      }}
      {{swipe onDidSwipe=this.didSwipe onDidEndSwipe=this.didEndSwipe}}
      data-test-duration={{this.duration}}
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
