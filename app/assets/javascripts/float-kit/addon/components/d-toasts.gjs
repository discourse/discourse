import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
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

  constructor(owner, args) {
    super(owner, args);

    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, _, { close, duration }) {
    this.element = element;
    this.close = close;
    this.duration = duration;
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
    this.transitionLaterHandler = discourseLater(() => {
      this.element.classList.add(TRANSITION_CLASS);

      this.closeLaterHandler = discourseLater(() => {
        this.close();
      }, CSS_TRANSITION_DELAY_MS);
    }, this.duration);
  }

  @bind
  stopTimer() {
    cancel(this.transitionLaterHandler);
    cancel(this.closeLaterHandler);
  }

  cleanup() {
    this.stopTimer();
    this.element.removeEventListener("mouseenter", this.stopTimer);
    this.element.removeEventListener("mouseleave", this.startTimer);
  }
}

export default class DToasts extends Component {
  @service toasts;

  <template>
    <section class="fk-d-toasts">
      {{#each this.toasts.activeToasts as |toast|}}
        <output
          role={{if toast.options.autoClose "status" "log"}}
          key={{toast.id}}
          class={{concatClass "fk-d-toast" toast.options.class}}
          {{(if
            toast.options.autoClose
            (modifier
              AutoCloseToast close=toast.close duration=toast.options.duration
            )
          )}}
        >
          <toast.options.component
            @data={{toast.options.data}}
            @duration={{toast.options.duration}}
            @close={{toast.close}}
          />
        </output>
      {{/each}}
    </section>
  </template>
}
