import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import swipe from "discourse/modifiers/swipe";
import autoCloseToast from "float-kit/modifiers/auto-close-toast";

const CLOSE_SWIPE_THRESHOLD = 50;

export default class DToast extends Component {
  @service site;

  @tracked progressBar;

  animating = false;

  @action
  registerProgressBar(element) {
    this.progressBar = element;
  }

  @action
  async handleSwipe(state) {
    if (this.animating) {
      return;
    }

    if (state.deltaY < 0) {
      this.#animateWrapperPosition(state.element, 0);
      return;
    }

    if (state.deltaY > CLOSE_SWIPE_THRESHOLD) {
      this.#close(state.element);
    } else {
      await this.#animateWrapperPosition(state.element, state.deltaY);
    }
  }

  @action
  async handleSwipeEnded(state) {
    if (state.deltaY > CLOSE_SWIPE_THRESHOLD) {
      this.#close(state.element);
    } else {
      await this.#animateWrapperPosition(state.element, 0);
    }
  }

  async #close(element) {
    await this.#closeWrapperAnimation(element);
    this.args.toast.close();
  }

  async #closeWrapperAnimation(element) {
    this.animating = true;

    await element.animate([{ transform: "translateY(-150px)" }], {
      fill: "forwards",
      duration: 250,
    }).finished;

    this.animating = false;
  }

  async #animateWrapperPosition(element, position) {
    this.animating = true;

    await element.animate([{ transform: `translateY(${-position}px)` }], {
      fill: "forwards",
    }).finished;

    this.animating = false;
  }

  <template>
    <output
      role={{if @toast.options.autoClose "status" "log"}}
      key={{@toast.id}}
      class={{concatClass "fk-d-toast" @toast.options.class}}
      {{autoCloseToast
        close=@toast.close
        duration=@toast.options.duration
        progressBar=this.progressBar
        enabled=@toast.options.autoClose
      }}
      {{swipe
        didSwipe=this.handleSwipe
        didEndSwipe=this.handleSwipeEnded
        enabled=this.site.mobileView
      }}
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
