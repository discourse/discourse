import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import type { TrustedHTML } from "@ember/template";
import { waitForPromise } from "@ember/test-waiters";
import { modifier as modifierFn } from "ember-modifier";
import htmlClass from "discourse/helpers/html-class";
import { waitForAnimationEnd } from "discourse/lib/animation-utils";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import {
  dampenedOverdrag,
  getMaxAnimationTimeMs,
  shouldDeferSwipeToContent,
} from "discourse/lib/swipe-events";
import type Site from "discourse/models/site";
import type AppEventsService from "discourse/services/app-events";
import type { CapabilitiesService } from "discourse/services/capabilities";
import type ModalService from "discourse/services/modal";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalInElement from "discourse/ui-kit/d-conditional-in-element";
import DFlashMessage, {
  type FlashType,
} from "discourse/ui-kit/d-flash-message";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dSwipe, { type SwipeState } from "discourse/ui-kit/modifiers/d-swipe";
import dTrapTab from "discourse/ui-kit/modifiers/d-trap-tab";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";
export const CLOSE_INITIATED_BY_SWIPE_DOWN = "initiatedBySwipeDown";

const SWIPE_VELOCITY_THRESHOLD = 0.4;
const SWIPE_CLOSE_DISTANCE_RATIO = 0.25;
const SWIPE_SETTLE_EASING = "cubic-bezier(0.32, 0.72, 0, 1)";

// The consumer's close handler. DModal invokes it with an `initiatedBy` reason, but the
// closers consumers pass (the modal service's `close`, or a float that renders DModal as its
// mobile fallback) accept their own argument shapes, so this is a deliberately broad relay type.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type CloseModalCallback = (...args: any[]) => void;

interface DModalSignature {
  /** The wrapper element: a `div` or `form`, per `@tagName`. */
  Element: HTMLDivElement | HTMLFormElement;
  Args: {
    /**
     * Called to close the modal, receiving the reason it was initiated by.
     * Providing it makes the modal dismissable by default.
     */
    closeModal?: CloseModalCallback;

    /**
     * Called before the modal closes, receiving the initiating reason.
     * Returning `false` cancels the close.
     */
    beforeClose?: (args: {
      initiatedBy: string;
    }) => boolean | void | Promise<boolean | void>;

    /**
     * Whether the modal can be dismissed via the close button, Escape, a
     * backdrop click, or a swipe down. Defaults to `true` when `@closeModal`
     * is set.
     */
    dismissable?: boolean;

    /** Whether to focus the first focusable element on open. Defaults to `true`. */
    autofocus?: boolean;

    /** Whether pressing Enter triggers the footer's primary action. Defaults to `true`. */
    submitOnEnter?: boolean;

    /** Whether the modal is hidden; while hidden it ignores keyboard events. */
    hidden?: boolean;

    /** Whether to render in place rather than in the modal container. */
    inline?: boolean;

    /** The wrapper element tag. Defaults to `"div"`. */
    tagName?: "div" | "form";

    /** The modal title. */
    title?: string;

    /** The subtitle shown under the title. */
    subtitle?: string;

    /** Whether to hide the header. */
    hideHeader?: boolean;

    /** Whether to hide the footer. */
    hideFooter?: boolean;

    /** Extra class applied to the header. */
    headerClass?: string;

    /** Extra class applied to the body. */
    bodyClass?: string;

    /** A flash message shown above the body. Accepts a plain string or trusted HTML. */
    flash?: string | TrustedHTML;

    /** The severity of the `@flash` message. */
    flashType?: FlashType;
  };
  Blocks: {
    /** The modal body, used when no `body` block is provided. */
    default: [];

    /** Rendered at the top of the modal, above the header. */
    aboveHeader: [];

    /** Rendered inside the header, above the title. */
    headerAboveTitle: [];

    /** Rendered as the header's primary action, on mobile. */
    headerPrimaryAction: [];

    /** Rendered below the title. */
    belowModalTitle: [];

    /** Rendered inside the header, below the title. */
    headerBelowTitle: [];

    /** Rendered below the header, before the flash and body. */
    belowHeader: [];

    /** The modal body. Takes precedence over the default block. */
    body: [];

    /** Rendered above the footer. */
    aboveFooter: [];

    /** The footer content. */
    footer: [];

    /** Rendered below the footer. */
    belowFooter: [];
  };
}

export default class DModal extends Component<DModalSignature> {
  @service declare appEvents: AppEventsService;
  @service declare capabilities: CapabilitiesService;
  @service declare modal: ModalService;
  @service declare site: Site;

  @tracked animating = false;
  registerModalContainer = modifierFn((el: HTMLElement) => {
    this.#modalContainer = el;
  });
  setupModalBody = modifierFn((el: HTMLElement) => {
    if (this.site.desktopView) {
      return;
    }

    // `body-scroll-lock` is a vendored bundle whose optional `options` argument is typed as
    // required; passing `undefined` keeps the original single-argument call.
    lock(el, undefined);

    if (this.capabilities.isIOS) {
      this.#lockedScrollY = window.scrollY;
      this.appEvents.on(
        "keyboard-visibility-change",
        this,
        this.resetDocumentScrollOnIOS
      );
    }

    return () => {
      unlock(el, undefined);

      if (this.capabilities.isIOS) {
        this.appEvents.off(
          "keyboard-visibility-change",
          this,
          this.resetDocumentScrollOnIOS
        );
      }
    };
  });
  #modalContainer: HTMLElement;
  #lockedScrollY?: number;
  @tracked _wrapperElement?: HTMLElement;

  get autofocus() {
    return this.args.autofocus ?? true;
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

  get mobileDismissable() {
    return this.site.mobileView && this.dismissable;
  }

  @action
  resetDocumentScrollOnIOS(visible: boolean) {
    // iOS scrolls the page to the focused input when the keyboard opens
    // as a result when an input is within a dropdown within a modal, the modal is scrolled out of view.
    // This forces the modal back to the correct visible position.
    if (!visible) {
      return;
    }

    window.scrollTo(0, this.#lockedScrollY ?? 0);
  }

  @action
  async setupModal(el: HTMLElement) {
    document.documentElement.addEventListener(
      "keydown",
      this.handleDocumentKeydown,
      { capture: true }
    );

    this._wrapperElement = el;
    this.animating = true;

    this.#modalContainer.classList.add("is-entering");
    await waitForAnimationEnd(this.#modalContainer);
    this.#modalContainer.classList.remove("is-entering");

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

  @action
  handleSwipeStart(swipeState: SwipeState, event: Event) {
    if (shouldDeferSwipeToContent(swipeState, this.#modalContainer)) {
      event.preventDefault();
    }
  }

  @action
  async handleSwipe(swipeEvent: SwipeState) {
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
  async handleSwipeEnded(swipeEvent: SwipeState) {
    if (this.animating) {
      // if the modal is animating we don't want to risk resetting the position
      // as the user releases the swipe at the same time
      return;
    }

    const closeDistance =
      this.#modalContainer.clientHeight * SWIPE_CLOSE_DISTANCE_RATIO;

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
  handleWrapperPointerDown(e: PointerEvent) {
    // prevents hamburger menu to close on modal backdrop click
    e.stopPropagation();
  }

  @action
  handleWrapperClick(e: MouseEvent) {
    if (e.button !== 0) {
      return; // Non-default mouse button
    }

    if (!this.dismissable) {
      return;
    }

    return this.closeModal(CLOSE_INITIATED_BY_CLICK_OUTSIDE);
  }

  @action
  async closeModal(initiatedBy: string) {
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
        const backdrop = this._wrapperElement?.nextElementSibling;
        this.#modalContainer.classList.add("is-exiting");
        if (backdrop) {
          backdrop.classList.add("is-exiting");
        }

        await waitForAnimationEnd(this.#modalContainer);
      }
    } finally {
      this.animating = false;
      this.args.closeModal({ initiatedBy });
    }
  }

  @action
  handleDocumentKeydown(event: KeyboardEvent) {
    if (this.args.hidden) {
      return;
    }

    // Prevent keyboard events from leaking to elements behind the modal.
    // Allow events when focus is inside another modal stacked above this one,
    // or inside a float-kit portal (menu/tooltip) opened from this modal,
    // since those render outside the modal DOM.
    if (
      !this._wrapperElement?.contains(document.activeElement) &&
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

    if (event.key === "Enter" && this.#shouldTriggerClickOnEnter(event)) {
      this._wrapperElement
        ?.querySelector<HTMLElement>(".d-modal__footer .btn-primary")
        ?.click();
      event.preventDefault();
    }
  }

  @action
  handleCloseButton() {
    this.closeModal(CLOSE_INITIATED_BY_BUTTON);
  }

  #shouldTriggerClickOnEnter(event: KeyboardEvent) {
    if (this.args.submitOnEnter === false) {
      return false;
    }

    // skip when in a form, textarea, or select-kit element
    if (
      (event.target as HTMLElement)?.closest("form") ||
      document.activeElement?.closest("form") ||
      document.activeElement?.nodeName === "TEXTAREA" ||
      document.activeElement?.closest(".select-kit")
    ) {
      return false;
    }

    return true;
  }

  #animateBackdropOpacity(position: number) {
    const backdrop = this._wrapperElement?.nextElementSibling;

    if (!backdrop) {
      return;
    }

    const opacity = 1 - position / this.#modalContainer.clientHeight;

    waitForPromise(
      backdrop.animate([{ opacity: Math.max(0, Math.min(opacity, 0.6)) }], {
        fill: "forwards",
      }).finished
    );
  }

  async #animateWrapperPosition(position: number, duration: number) {
    this.#animateBackdropOpacity(position);

    await waitForPromise(
      this.#modalContainer.animate(
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
    const backdrop = this._wrapperElement?.nextElementSibling;

    if (backdrop) {
      waitForPromise(
        backdrop.animate([{ opacity: 0 }], { fill: "forwards", duration })
          .finished
      );
    }

    await waitForPromise(
      this.#modalContainer.animate([{ transform: "translateY(100%)" }], {
        fill: "forwards",
        duration,
        easing: SWIPE_SETTLE_EASING,
      }).finished
    );
  }

  async #animatePopOff() {
    const backdrop = this._wrapperElement?.nextElementSibling;

    if (!backdrop) {
      return;
    }

    this.#modalContainer.classList.add("is-exiting");
    backdrop.classList.add("is-exiting");

    await waitForPromise(
      Promise.all([
        waitForAnimationEnd(this.#modalContainer),
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
