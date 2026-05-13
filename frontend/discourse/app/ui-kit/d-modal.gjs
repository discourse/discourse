// @ts-check
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
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
/** @type {import("discourse/ui-kit/helpers/d-element.gjs").default} */
import dElement from "discourse/ui-kit/helpers/d-element";
import dSwipe from "discourse/ui-kit/modifiers/d-swipe";
import dTrapTab from "discourse/ui-kit/modifiers/d-trap-tab";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";
export const CLOSE_INITIATED_BY_SWIPE_DOWN = "initiatedBySwipeDown";

const ALLOWED_TAG_NAMES = ["div", "form"];

const SWIPE_VELOCITY_THRESHOLD = 0.4;

/**
 * The standard modal dialog. Renders an absolute-positioned dialog with a
 * backdrop, a header (optional close button, title, subtitle), a body slot,
 * and a footer slot. Handles focus trapping, body-scroll locking on mobile,
 * Escape-to-close, Enter-to-submit, click-outside dismissal, and swipe-down
 * dismissal on touch devices.
 *
 * Most consumers go through `service modal` which mounts a modal component
 * for them; `DModal` itself is the building block that those modal
 * components yield from their template.
 *
 * `@closeModal` is the single close callback — it fires with one argument
 * `{ initiatedBy: "<reason>" }` where the reason is one of the exported
 * `CLOSE_INITIATED_BY_*` constants. Provide `@beforeClose` to veto specific
 * close attempts (e.g. unsaved changes prompt).
 *
 * @example
 * <DModal @closeModal={{@closeModal}} @title="Confirm delete">
 *   <:body>Are you sure?</:body>
 *   <:footer>
 *     <DButton @label="cancel" @action={{@closeModal}} />
 *     <DButton @label="delete" class="btn-danger" @action={{this.confirm}} />
 *   </:footer>
 * </DModal>
 */

/**
 * @typedef DModalSignature
 *
 * @property {object} Args
 *
 * Identity and content
 *
 * @property {string} [Args.title] Translated dialog title rendered in the header. Drives `aria-labelledby`.
 * @property {string} [Args.subtitle] Translated subtitle rendered below the title.
 * @property {"div"|"form"} [Args.tagName] Root tag. Use `"form"` when the dialog wraps form submission. Defaults to `"div"`.
 *
 * Close lifecycle
 *
 * @property {(payload: {initiatedBy: string}) => void} [Args.closeModal] Invoked when the modal should close. Receives a payload with the trigger reason. Omitting this disables all dismiss mechanisms.
 * @property {(payload: {initiatedBy: string}) => boolean | Promise<boolean>} [Args.beforeClose] Invoked before each close attempt. Return (or resolve to) `false` to veto.
 * @property {boolean} [Args.dismissable] Whether the user can dismiss the modal (close button, Escape, click-outside, swipe). Defaults to `true` when `@closeModal` is set.
 * @property {boolean} [Args.submitOnEnter] When `true` (the default), pressing Enter outside form/textarea/select-kit focus triggers the footer's primary button.
 *
 * Layout
 *
 * @property {boolean} [Args.inline] When `true`, the modal renders inline at its call-site rather than being teleported to the modal container. Used for in-page sub-dialogs.
 * @property {boolean} [Args.autofocus] When `true` (the default), focus is moved into the modal on mount.
 * @property {boolean} [Args.hidden] When `true`, document-level keyboard handlers are bypassed. Used by the modal service when stacking modals.
 * @property {boolean} [Args.hideHeader] Hides the header block entirely (no title, no close button).
 * @property {boolean} [Args.hideFooter] Hides the `<:footer>` block region even if the consumer yields it.
 * @property {string} [Args.headerClass] Extra classes joined onto the `.d-modal__header` element.
 * @property {string} [Args.bodyClass] Extra classes joined onto the `.d-modal__body` element.
 *
 * Flash
 *
 * @property {string} [Args.flash] Inline flash message rendered between header and body.
 * @property {"success"|"error"|"warning"|"info"} [Args.flashType] Flash variant.
 *
 * @property {HTMLDivElement | HTMLFormElement} Element The root dialog element. Type depends on `@tagName`.
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Body content when no `<:body>` named block is provided.
 * @property {[]} Blocks.aboveHeader Rendered above the header. Use sparingly — most callers should put content in `<:body>`.
 * @property {[]} Blocks.headerAboveTitle Rendered inside the header, above the title row.
 * @property {[]} Blocks.belowModalTitle Rendered inside the title block, after the subtitle.
 * @property {[]} Blocks.headerBelowTitle Rendered inside the header, below the title row.
 * @property {[]} Blocks.headerPrimaryAction Rendered on the right edge of the header on mobile. On desktop the dismiss button takes this slot; on mobile this block replaces it.
 * @property {[]} Blocks.belowHeader Rendered between the header and the flash region.
 * @property {[]} Blocks.body Main content area. When omitted, the default block is used instead.
 * @property {[]} Blocks.footer Footer content. The footer is only rendered when this block is present.
 * @property {[]} Blocks.belowFooter Rendered after the footer.
 */

/** @extends {Component<DModalSignature>} */
export default class DModal extends Component {
  @service appEvents;
  @service capabilities;
  @service modal;
  @service site;

  @tracked wrapperElement;
  @tracked animating = false;

  /** @type {HTMLElement} */
  modalContainer;

  registerModalContainer = modifierFn((el) => {
    this.modalContainer = /** @type {HTMLElement} */ (el);
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

  @cached
  get validateArgs() {
    if (DEBUG) {
      assert(
        "[d-modal] @closeModal must be a function when provided",
        !this.args.closeModal || typeof this.args.closeModal === "function"
      );
      assert(
        "[d-modal] @beforeClose must be a function when provided",
        !this.args.beforeClose || typeof this.args.beforeClose === "function"
      );
    }
    return null;
  }

  @action
  resetDocumentScrollOnIOS(visible) {
    // iOS scrolls the page to the focused input when the keyboard opens.
    // When an input is inside a dropdown inside a modal, that scroll pushes
    // the modal off-screen. This forces the page back to its locked position.
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

    // Skip Enter-to-submit when focus is inside a form, textarea, or
    // select-kit — those have their own Enter semantics.
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
      // If the modal is animating we don't want to risk resetting the
      // position as the user releases the swipe at the same time.
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
  }

  @action
  handleWrapperPointerDown(e) {
    // Prevent the hamburger menu from closing when the modal backdrop is
    // clicked — the click bubbles through the portal otherwise.
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
    // Allow events when focus is inside a float-kit portal (menu/tooltip)
    // opened from this modal, since those render outside the modal DOM.
    if (
      !this.wrapperElement.contains(document.activeElement) &&
      !document.activeElement?.closest(
        ".fk-d-menu, .fk-d-menu-modal, .fk-d-tooltip"
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

  // Could be optimised to remove the classic component path once RFC389
  // (dynamic tag names) ships: https://rfcs.emberjs.com/id/0389-dynamic-tag-names
  @cached
  get dynamicElement() {
    const tagName = this.args.tagName || "div";
    if (!ALLOWED_TAG_NAMES.includes(tagName)) {
      throw `@tagName must be form or div`;
    }

    return dElement(tagName);
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
    {{! template-lint-disable no-invalid-interactive }}
    {{! @glint-nocheck: complex template — render-modifier and dSwipe signatures don't match Glint's stricter typing }}
    {{this.validateArgs}}

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
        {{dTrapTab preventScroll=false autofocus=this.autofocus}}
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
              class={{dConcatClass
                "d-modal__header"
                (if
                  (and this.mobileDismissable (has-block "headerPrimaryAction"))
                  "--has-primary-action"
                )
                @headerClass
              }}
              {{dSwipe
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
          {{dSwipe
            onDidSwipe=this.handleSwipe
            onDidEndSwipe=this.handleSwipeEnded
            enabled=this.dismissable
          }}
          {{on "click" this.handleWrapperClick}}
          {{! template-lint-disable no-pointer-down-event-binding }}
          {{on "pointerdown" this.handleWrapperPointerDown}}
        ></div>
      {{/unless}}
    </DConditionalInElement>
  </template>
}
