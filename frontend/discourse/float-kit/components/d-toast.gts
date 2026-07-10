import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type { ModifierLike } from "@glint/template";
import type DToastInstance from "discourse/float-kit/lib/d-toast-instance";
import autoCloseToast from "discourse/float-kit/modifiers/auto-close-toast";
import deprecated from "discourse/lib/deprecated";
import { getMaxAnimationTimeMs } from "discourse/lib/swipe-events";
import { and } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dSwipeUntyped from "discourse/ui-kit/modifiers/d-swipe";

const VELOCITY_THRESHOLD = -1.2;

/** The swipe state the `d-swipe` modifier reports to its callbacks. */
interface SwipeState {
  element: HTMLElement;
  deltaY: number;
  velocityY: number;
}

// TODO(devxp-typescript-pending): drop this cast once d-swipe is authored in .ts with a
// real Signature, then import it directly. Untyped .js today gives it no arg types.
const dSwipe = dSwipeUntyped as unknown as ModifierLike<{
  Element: HTMLElement;
  Args: {
    Named: {
      onDidSwipe?: (state: SwipeState) => void;
      onDidEndSwipe?: (state: SwipeState) => void;
    };
  };
}>;

interface DToastSignature {
  Args: {
    toast: DToastInstance;
  };
}

export default class DToast extends Component<DToastSignature> {
  @tracked progressBar?: HTMLElement;

  @action
  registerProgressBar(element: HTMLElement) {
    this.progressBar = element;
  }

  @action
  async didSwipe(state: SwipeState) {
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
  async didEndSwipe(state: SwipeState) {
    if (state.velocityY < VELOCITY_THRESHOLD) {
      await this.#close(state.element);
    } else {
      await this.#animateWrapperPosition(state.element, 0);
    }
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

  async #close(element: HTMLElement) {
    await this.#closeWrapperAnimation(element);
    this.args.toast.close();
  }

  async #closeWrapperAnimation(element: HTMLElement) {
    await element.animate([{ transform: "translateY(-150px)" }], {
      fill: "forwards",
      duration: getMaxAnimationTimeMs(),
    }).finished;
  }

  async #animateWrapperPosition(element: HTMLElement, position: number) {
    await element.animate([{ transform: `translateY(${position}px)` }], {
      fill: "forwards",
    }).finished;
  }

  <template>
    <output
      role={{if @toast.options.autoClose "status" "log"}}
      class={{dConcatClass "fk-d-toast" @toast.options.class}}
      {{autoCloseToast
        close=@toast.close
        duration=this.duration
        progressBar=this.progressBar
        enabled=@toast.options.autoClose
      }}
      {{dSwipe onDidSwipe=this.didSwipe onDidEndSwipe=this.didEndSwipe}}
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
