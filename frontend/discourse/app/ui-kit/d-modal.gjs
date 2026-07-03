import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { modifier as modifierFn } from "ember-modifier";
import htmlClass from "discourse/helpers/html-class";
import { waitForAnimationEnd } from "discourse/lib/animation-utils";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import { getMaxAnimationTimeMs } from "discourse/lib/swipe-events";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dSwipe from "discourse/ui-kit/modifiers/d-swipe";
import dTrapTab from "discourse/ui-kit/modifiers/d-trap-tab";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";
export const CLOSE_INITIATED_BY_SWIPE_DOWN = "initiatedBySwipeDown";

const SWIPE_VELOCITY_THRESHOLD = 0.4;
const SWIPE_CLOSE_DISTANCE_RATIO = 0.25;
const SWIPE_SETTLE_EASING = "cubic-bezier(0.32, 0.72, 0, 1)";

// progressive resistance when the modal is dragged past its resting position
function dampenedOverdrag(distance) {
  return Math.max(0, 8 * (Math.log(distance + 1) - 2));
}

export default class DModal extends Component {
  @service appEvents;
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

    lock(el);

    if (this.capabilities.isIOS) {
      this.lockedScrollY = window.scrollY;
      this.appEvents.on(
        "keyboard-visibility-change",
        this,
        this.resetDocumentScrollOnIOS
      );
    }

    return () => {
      unlock(el);

      if (this.capabilities.isIOS) {
        this.appEvents.off(
          "keyboard-visibility-change",
          this,
          this.resetDocumentScrollOnIOS
        );
      }
    };
  });

  @action
  resetDocumentScrollOnIOS(visible) {
    // iOS scrolls the page to the focused input when the keyboard opens
    // as a result when an input is within a dropdown within a modal, the modal is scrolled out of view.
    // This forces the modal back to the correct visible position.
    if (!visible) {
      return;
    }

    window.scrollTo(0, this.lockedScrollY ?? 0);
  }

  @action
  async setupModal(el) {
    document.documentElement.addEventListener(
      "keydown",
      this.handleDocumentKeydown,
      { capture: true }
    );

    this.wrapperElement = el;
    this.animating = true;

    this.modalContainer.classList.add("is-entering");
    await waitForAnimationEnd(this.modalContainer);
    this.modalContainer.classList.remove("is-entering");

    this.animating = false;
  }

  @action
  cleanupModal() {
    document.documentElement.removeEventListener(
      "keydown",
      this.handleDocumentKeydown,
      { capture: true }
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

    // skip when in a form, textarea, or select-kit element
    if (
      event.target.closest("form") ||
      document.activeElement?.closest("form") ||
      document.activeElement?.nodeName === "TEXTAREA" ||
      document.activeElement?.closest(".select-kit")
    ) {
      return false;
    }

    return true;
  }

  @action
  handleSwipeStart(swipeState, event) {
    if (this.#shouldDeferSwipeToContent(swipeState)) {
      event.preventDefault();
    }
  }

  @action
  async handleSwipe(swipeEvent) {
    if (this.animating) {
      return;
    }

    // applied instantly so the modal tracks the finger 1:1; easing only
    // happens when the gesture ends
    const position =
      swipeEvent.deltaY >= 0
        ? swipeEvent.deltaY
        : -dampenedOverdrag(-swipeEvent.deltaY);

    await this.#animateWrapperPosition(position, 0);
  }

  @action
  async handleSwipeEnded(swipeEvent) {
    if (this.animating) {
      // if the modal is animating we don't want to risk resetting the position
      // as the user releases the swipe at the same time
      return;
    }

    const closeDistance =
      this.modalContainer.clientHeight * SWIPE_CLOSE_DISTANCE_RATIO;

    if (
      swipeEvent.goingUp() ||
      swipeEvent.deltaY <= 0 ||
      (swipeEvent.velocityY < SWIPE_VELOCITY_THRESHOLD &&
        swipeEvent.deltaY < closeDistance)
    ) {
      return await this.#animateWrapperPosition(0, getMaxAnimationTimeMs());
    }

    this.closeModal(CLOSE_INITIATED_BY_SWIPE_DOWN);
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
  }

  @action
  async closeModal(initiatedBy) {
    if (!this.args.closeModal) {
      return;
    }

    if (this.args.beforeClose) {
      const canClose = await this.args.beforeClose({ initiatedBy });
      if (canClose === false) {
        return;
      }
    }

    try {
      this.animating = true;

      if (this.site.desktopView) {
        await this.#animatePopOff();
      } else if (initiatedBy === CLOSE_INITIATED_BY_SWIPE_DOWN) {
        await this.#animateSwipeDismiss();
      } else {
        const backdrop = this.wrapperElement.nextElementSibling;
        this.modalContainer.classList.add("is-exiting");
        if (backdrop) {
          backdrop.classList.add("is-exiting");
        }

        await waitForAnimationEnd(this.modalContainer);
      }
    } finally {
      this.animating = false;
      this.args.closeModal({ initiatedBy });
    }
  }

  @action
  handleDocumentKeydown(event) {
    if (this.args.hidden) {
      return;
    }

    // Prevent keyboard events from leaking to elements behind the modal.
    // Allow events when focus is inside another modal stacked above this one,
    // or inside a float-kit portal (menu/tooltip) opened from this modal,
    // since those render outside the modal DOM.
    if (
      !this.wrapperElement.contains(document.activeElement) &&
      !document.activeElement?.closest(
        ".d-modal, .fk-d-menu, .fk-d-menu-modal, .fk-d-tooltip"
      )
    ) {
      event.stopPropagation();
      event.preventDefault();
    }

    if (event.key === "Escape" && this.dismissable) {
      event.stopPropagation();
      this.closeModal(CLOSE_INITIATED_BY_ESC);
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

    return dElement(tagName);
  }

  // lets inner content consume the gesture instead of dragging the modal:
  // horizontal swipes, and vertical swipes started within scrollable content
  // that can still scroll in the gesture's direction
  #shouldDeferSwipeToContent(swipeState) {
    if (swipeState.direction === "left" || swipeState.direction === "right") {
      return true;
    }

    let element = swipeState.originalEvent?.target;

    while (element && element !== this.modalContainer) {
      if (element.scrollHeight > element.clientHeight) {
        const { overflowY } = window.getComputedStyle(element);

        if (overflowY === "auto" || overflowY === "scroll") {
          if (swipeState.direction === "down" && element.scrollTop > 0) {
            return true;
          }

          if (
            swipeState.direction === "up" &&
            element.scrollTop + element.clientHeight < element.scrollHeight
          ) {
            return true;
          }
        }
      }

      element = element.parentElement;
    }

    return false;
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

  async #animateWrapperPosition(position, duration) {
    this.#animateBackdropOpacity(position);

    await waitForPromise(
      this.modalContainer.animate(
        [{ transform: `translateY(${position}px)` }],
        {
          fill: "forwards",
          duration,
          easing: SWIPE_SETTLE_EASING,
        }
      ).finished
    );
  }

  // dismisses from the current dragged position; the `is-exiting` CSS
  // animation can't be used here as it animates from translateY(0) and is
  // overridden by the drag's fill-forwards animations anyway
  async #animateSwipeDismiss() {
    const duration = getMaxAnimationTimeMs();
    const backdrop = this.wrapperElement.nextElementSibling;

    if (backdrop) {
      waitForPromise(
        backdrop.animate([{ opacity: 0 }], { fill: "forwards", duration })
          .finished
      );
    }

    await waitForPromise(
      this.modalContainer.animate([{ transform: "translateY(100%)" }], {
        fill: "forwards",
        duration,
        easing: SWIPE_SETTLE_EASING,
      }).finished
    );
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
        waitForAnimationEnd(this.modalContainer),
        waitForAnimationEnd(backdrop),
      ])
    );
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}

    <DConditionalInElement
      @element={{this.modal.containerElement}}
      @inline={{@inline}}
      @append={{true}}
    >
      {{#unless @inline}}
        {{htmlClass "modal-open"}}
      {{/unless}}
      <this.dynamicElement
        class={{dConcatClass
          "modal d-modal"
          (if this.animating "is-animating")
        }}
        data-keyboard="false"
        aria-modal="true"
        role="dialog"
        aria-labelledby={{if @title "discourse-modal-title"}}
        ...attributes
        {{didInsert this.setupModal}}
        {{willDestroy this.cleanupModal}}
        {{dTrapTab preventScroll=false autofocus=this.autofocus}}
      >
        <div
          class="d-modal__container"
          {{this.registerModalContainer}}
          {{dSwipe
            onDidStartSwipe=this.handleSwipeStart
            onDidSwipe=this.handleSwipe
            onDidEndSwipe=this.handleSwipeEnded
            enabled=this.dismissable
          }}
        >
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
              class={{dConcatClass
                "d-modal__header"
                (if
                  (and this.mobileDismissable (has-block "headerPrimaryAction"))
                  "--has-primary-action"
                )
                @headerClass
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

          <DFlashMessage
            id="modal-alert"
            role="alert"
            @flash={{@flash}}
            @type={{@flashType}}
          />

          <div
            class={{dConcatClass "d-modal__body" @bodyClass}}
            tabindex="-1"
            {{this.setupModalBody}}
          >
            {{#if (has-block "body")}}
              {{yield to="body"}}
            {{else}}
              {{yield}}
            {{/if}}
          </div>

          {{#if (and (has-block "aboveFooter") (not @hideFooter))}}
            {{yield to="aboveFooter"}}
          {{/if}}

          {{#if (and (has-block "footer") (not @hideFooter))}}
            <div class="d-modal__footer">
              {{yield to="footer"}}
            </div>
          {{/if}}

          {{yield to="belowFooter"}}
        </div>
      </this.dynamicElement>
      {{#unless @inline}}
        {{! eslint-disable ember/template-no-pointer-down-event-binding }}
        <div
          class="d-modal__backdrop"
          {{dSwipe
            onDidSwipe=this.handleSwipe
            onDidEndSwipe=this.handleSwipeEnded
            enabled=this.dismissable
          }}
          {{on "click" this.handleWrapperClick}}
          {{on "pointerdown" this.handleWrapperPointerDown}}
        ></div>
      {{/unless}}
    </DConditionalInElement>
  </template>
}
