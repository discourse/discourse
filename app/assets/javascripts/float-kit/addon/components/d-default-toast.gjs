import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";
import swipe from "discourse/modifiers/swipe";
import icon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";

const MIN_SWIPE_THRESHOLD = 10;

export default class DDefaultToast extends Component {
  @service site;

  animating = false;
  scrollLocked = false;
  swipeEnabled = this.site.mobileView;

  setupToast = modifier((element) => {
    this.wrapperElement = element.parentElement;
    this.wrapperElement.addEventListener("touchstart", this.toggleLock);

    return () => {
      this.wrapperElement.removeEventListener("touchstart", this.toggleLock);
    };
  });

  @action
  handleSwipe(state) {
    if (!this.site.mobileView || this.animating) {
      return;
    }

    if (state.deltaY > MIN_SWIPE_THRESHOLD) {
      this.#animateWrapperPosition();
      return;
    }
  }

  @action
  handleSwipeEnded(state) {
    if (!this.site.mobileView) {
      return;
    }

    this.toggleLock();

    if (state.deltaY > MIN_SWIPE_THRESHOLD) {
      this.args.close();
    }
  }

  async #animateWrapperPosition() {
    this.animating = true;

    await this.wrapperElement.animate([{ transform: `translateY(-150px)` }], {
      duration: 500,
      fill: "forwards",
    });

    this.animating = false;
  }

  @bind
  toggleLock() {
    if (!this.site.mobileView) {
      return;
    }

    if (this.scrollLocked) {
      enableBodyScroll(this.wrapperElement);
    } else {
      disableBodyScroll(this.wrapperElement);
    }

    this.scrollLocked = !this.scrollLocked;
  }

  <template>
    <div
      class={{concatClass
        "fk-d-default-toast"
        (concat "-" (or @data.theme "default"))
      }}
      ...attributes
      {{swipe
        didSwipe=this.handleSwipe
        didEndSwipe=this.handleSwipeEnded
        enabled=this.swipeEnabled
      }}
      {{this.setupToast}}
    >
      {{#if @showProgressBar}}
        <div
          class="fk-d-default-toast__progress-bar"
          {{didInsert @onRegisterProgressBar}}
        ></div>
      {{/if}}
      {{#if @data.icon}}
        <div class="fk-d-default-toast__icon-container">
          {{icon @data.icon}}
        </div>
      {{/if}}
      <div class="fk-d-default-toast__main-container">
        <div class="fk-d-default-toast__texts">
          {{#if @data.title}}
            <div class="fk-d-default-toast__title">
              {{@data.title}}
            </div>
          {{/if}}
          {{#if @data.message}}
            <div class="fk-d-default-toast__message">
              {{@data.message}}
            </div>
          {{/if}}
        </div>

        {{#if @data.actions}}
          <div class="fk-d-default-toast__actions">
            {{#each @data.actions as |toastAction|}}
              {{#if toastAction.action}}
                <DButton
                  @icon={{toastAction.icon}}
                  @translatedLabel={{toastAction.label}}
                  @action={{fn
                    toastAction.action
                    (hash data=@data close=@close)
                  }}
                  class={{toastAction.class}}
                  tabindex="0"
                />
              {{/if}}
            {{/each}}
          </div>
        {{/if}}
      </div>
      <div class="fk-d-default-toast__close-container">
        <DButton class="btn-transparent" @icon="times" @action={{@close}} />
      </div>
    </div>
  </template>
}
