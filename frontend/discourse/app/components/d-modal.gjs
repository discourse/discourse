import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { modifier as modifierFn } from "ember-modifier";
import ConditionalInElement from "discourse/components/conditional-in-element";
import DButton from "discourse/components/d-button";
import FlashMessage from "discourse/components/flash-message";
import concatClass from "discourse/helpers/concat-class";
import element from "discourse/helpers/element";
import htmlClass from "discourse/helpers/html-class";
import {
  disableBodyScroll,
  enableBodyScroll,
} from "discourse/lib/body-scroll-lock";
import { getMaxAnimationTimeMs } from "discourse/lib/swipe-events";
import swipe from "discourse/modifiers/swipe";
import trapTab from "discourse/modifiers/trap-tab";
import { and, not, or } from "discourse/truth-helpers";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";
export const CLOSE_INITIATED_BY_SWIPE_DOWN = "initiatedBySwipeDown";

const SWIPE_VELOCITY_THRESHOLD = 0.4;

export default class DModal extends Component {
  @service capabilities;
  @service modal;
  @service site;

  @tracked wrapperElement;
  @tracked animating = false;

  registerModalContainer = modifierFn((el) => {
    this.modalContainer = el;
  });

  setupModalBody = modifierFn((el) => {
    if (this.site.desktopView) {
      return;
    }

    let offset, interval;
    if (this.capabilities.isIOS) {
      offset = window.pageYOffset;
      interval = setInterval(() => {
        window.scrollTo(0, offset);
      }, 50);
    }

    disableBodyScroll(el);

    return () => {
      if (this.capabilities.isIOS) {
        clearInterval(interval);
      }

      enableBodyScroll(el);
    };
  });

  @action
  async setupModal(el) {
    document.documentElement.addEventListener(
      "keydown",
      this.handleDocumentKeydown
    );

    this.wrapperElement = el;
    this.animating = true;

    this.modalContainer.classList.add("is-entering");
    await this.#waitForAnimationEnd(this.modalContainer);
    this.modalContainer.classList.remove("is-entering");

    this.animating = false;
  }

  @action
  cleanupModal() {
    document.documentElement.removeEventListener(
      "keydown",
      this.handleDocumentKeydown
    );
  }

  get dismissable() {
    if (!this.args.closeModal) {
      return false;
    } else if ("dismissable" in this.args) {
      return this.args.dismissable;
    } else {
      return true;
    }
  }

  get autofocus() {
    return this.args.autofocus ?? true;
  }

  get mobileDismissable() {
    return this.site.mobileView && this.dismissable;
  }

  shouldTriggerClickOnEnter(event) {
    if (this.args.submitOnEnter === false) {
      return false;
    }

    // skip when in a form or a textarea element
    if (
      event.target.closest("form") ||
      document.activeElement?.nodeName === "TEXTAREA"
    ) {
      return false;
    }

    return true;
  }

  @action
  async handleSwipe(swipeEvent) {
    if (this.animating) {
      return;
    }

    if (swipeEvent.deltaY >= 0) {
      return await this.#animateWrapperPosition(swipeEvent.deltaY);
    }
  }

  @action
  async handleSwipeEnded(swipeEvent) {
    if (this.animating) {
      // if the modal is animating we don't want to risk resetting the position
      // as the user releases the swipe at the same time
      return;
    }

    if (
      swipeEvent.goingUp() ||
      swipeEvent.velocityY < SWIPE_VELOCITY_THRESHOLD
    ) {
      return await this.#animateWrapperPosition(0);
    }

    this.modalContainer.style.transform = `translateY(${swipeEvent.deltaY}px)`;
    this.closeModal(CLOSE_INITIATED_BY_SWIPE_DOWN);
    this.closeModal(CLOSE_INITIATED_BY_SWIPE_DOWN, swipeEvent);
  }

  @action
  handleWrapperPointerDown(e) {
    // prevents hamburger menu to close on modal backdrop click
    e.stopPropagation();
  }

  @action
  handleWrapperClick(e) {
    if (e.button !== 0) {
      return; // Non-default mouse button
    }

    if (!this.dismissable) {
      return;
    }

    return this.closeModal(CLOSE_INITIATED_BY_CLICK_OUTSIDE);
    return this.closeModal(CLOSE_INITIATED_BY_CLICK_OUTSIDE, e);
  }

  @action
  async closeModal(initiatedBy) {
  async closeModal(initiatedBy, event) {
    if (!this.args.closeModal) {
      return;
    }

    if (this.args.shouldClose) {
      const shouldClose = await this.args.shouldClose({ initiatedBy }, event);
      if (shouldClose === false) {
        return;
      }
    }

    try {
      this.animating = true;

      if (this.site.desktopView) {
        await this.#animatePopOff();
      } else {
        const backdrop = this.wrapperElement.nextElementSibling;
        this.modalContainer.classList.add("is-exiting");
        if (backdrop) {
          backdrop.classList.add("is-exiting");
        }

        await this.#waitForAnimationEnd(this.modalContainer);
      }
    } finally {
      this.animating = false;
      this.args.closeModal({ initiatedBy });
      this.args.closeModal({ initiatedBy }, event);
    }
  }

  @action
  handleDocumentKeydown(event) {
    if (this.args.hidden) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      event.stopPropagation();
      this.closeModal(CLOSE_INITIATED_BY_ESC);
      this.closeModal(CLOSE_INITIATED_BY_ESC, event);
    }

    if (event.key === "Enter" && this.shouldTriggerClickOnEnter(event)) {
      this.wrapperElement
        .querySelector(".d-modal__footer .btn-primary")
        ?.click();
      event.preventDefault();
    }
  }

  @action
  handleCloseButton() {
    this.closeModal(CLOSE_INITIATED_BY_BUTTON);
  }

  // Could be optimised to remove classic component once RFC389 is implemented
  // https://rfcs.emberjs.com/id/0389-dynamic-tag-names
  @cached
  get dynamicElement() {
    const tagName = this.args.tagName || "div";
    if (!["div", "form"].includes(tagName)) {
      throw `@tagName must be form or div`;
    }

    return element(tagName);
  }

  #animateBackdropOpacity(position) {
    const backdrop = this.wrapperElement.nextElementSibling;

    if (!backdrop) {
      return;
    }

    const opacity = 1 - position / this.modalContainer.clientHeight;

    waitForPromise(
      backdrop.animate([{ opacity: Math.max(0, Math.min(opacity, 0.6)) }], {
        fill: "forwards",
      }).finished
    );
  }

  async #animateWrapperPosition(position) {
    this.#animateBackdropOpacity(position);

    await waitForPromise(
      this.modalContainer.animate(
        [{ transform: `translateY(${position}px)` }],
        {
          fill: "forwards",
          duration: getMaxAnimationTimeMs(),
        }
      ).finished
    );
  }

  #waitForAnimationEnd(el) {
    return new Promise((resolve) => {
      const style = window.getComputedStyle(el);
      const duration = parseFloat(style.animationDuration) * 1000 || 0;
      const delay = parseFloat(style.animationDelay) * 1000 || 0;
      const totalTime = duration + delay;

      const timeoutId = setTimeout(
        () => {
          el.removeEventListener("animationend", handleAnimationEnd);
          resolve();
        },
        Math.max(totalTime + 50, 50)
      );

      const handleAnimationEnd = () => {
        clearTimeout(timeoutId);
        el.removeEventListener("animationend", handleAnimationEnd);
        resolve();
      };

      el.addEventListener("animationend", handleAnimationEnd);
    });
  }

  async #animatePopOff() {
    const backdrop = this.wrapperElement.nextElementSibling;

    if (!backdrop) {
      return;
    }

    this.modalContainer.classList.add("is-exiting");
    backdrop.classList.add("is-exiting");

    await waitForPromise(
      Promise.all([
        this.#waitForAnimationEnd(this.modalContainer),
        this.#waitForAnimationEnd(backdrop),
      ])
    );
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}

    <ConditionalInElement
      @element={{this.modal.containerElement}}
      @inline={{@inline}}
      @append={{true}}
    >
      {{#unless @inline}}
        {{htmlClass "modal-open"}}
      {{/unless}}
      <this.dynamicElement
        class={{concatClass
          "modal"
          "d-modal"
          (if @inline "-inline")
          (if this.animating "is-animating")
        }}
        data-keyboard="false"
        aria-modal="true"
        role="dialog"
        aria-labelledby={{if @title "discourse-modal-title"}}
        ...attributes
        {{didInsert this.setupModal}}
        {{willDestroy this.cleanupModal}}
        {{trapTab preventScroll=false autofocus=this.autofocus}}
      >
        <div class="d-modal__container" {{this.registerModalContainer}}>
          {{yield to="aboveHeader"}}

          {{#if
            (and
              (not @hideHeader)
              (or
                this.dismissable
                @title
                (has-block "headerBelowTitle")
                (has-block "headerAboveTitle")
              )
            )
          }}
            <div
              class={{concatClass
                "d-modal__header"
                (if
                  (and this.mobileDismissable (has-block "headerPrimaryAction"))
                  "--has-primary-action"
                )
                @headerClass
              }}
              {{swipe
                onDidSwipe=this.handleSwipe
                onDidEndSwipe=this.handleSwipeEnded
                enabled=this.dismissable
              }}
            >
              {{yield to="headerAboveTitle"}}

              {{#if
                (and this.mobileDismissable (has-block "headerPrimaryAction"))
              }}
                <div class="d-modal__dismiss-action">
                  <DButton
                    @label="cancel"
                    @action={{this.handleCloseButton}}
                    @title="modal.close"
                    class="btn-transparent d-modal__dismiss-action-button"
                  />
                </div>
              {{/if}}

              {{#if @title}}
                <div class="d-modal__title">
                  <h1
                    id="discourse-modal-title"
                    class="d-modal__title-text"
                  >{{@title}}</h1>

                  {{#if @subtitle}}
                    <p class="d-modal__subtitle-text">{{@subtitle}}</p>
                  {{/if}}

                  {{yield to="belowModalTitle"}}
                </div>
              {{/if}}
              {{yield to="headerBelowTitle"}}

              {{#if
                (and this.site.mobileView (has-block "headerPrimaryAction"))
              }}
                <div class="d-modal__primary-action">
                  {{yield to="headerPrimaryAction"}}
                </div>
              {{else if this.dismissable}}
                <DButton
                  @icon="xmark"
                  @action={{this.handleCloseButton}}
                  @title="modal.close"
                  class="btn-transparent modal-close"
                />
              {{/if}}
            </div>
          {{/if}}

          {{yield to="belowHeader"}}

          <FlashMessage
            id="modal-alert"
            role="alert"
            @flash={{@flash}}
            @type={{@flashType}}
          />

          <div
            class={{concatClass "d-modal__body" @bodyClass}}
            {{this.setupModalBody}}
            tabindex="-1"
          >
            {{#if (has-block "body")}}
              {{yield to="body"}}
            {{else}}
              {{yield}}
            {{/if}}
          </div>

          {{#if (and (has-block "footer") (not @hideFooter))}}
            <div class="d-modal__footer">
              {{yield to="footer"}}
            </div>
          {{/if}}

          {{yield to="belowFooter"}}
        </div>
      </this.dynamicElement>
      {{#unless @inline}}
        <div
          class="d-modal__backdrop"
          {{swipe
            onDidSwipe=this.handleSwipe
            onDidEndSwipe=this.handleSwipeEnded
            enabled=this.dismissable
          }}
          {{on "click" this.handleWrapperClick}}
          {{! template-lint-disable no-pointer-down-event-binding }}
          {{on "pointerdown" this.handleWrapperPointerDown}}
        ></div>
      {{/unless}}
    </ConditionalInElement>
  </template>
}
