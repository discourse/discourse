import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import ClassicComponent from "@ember/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { and, not, or } from "truth-helpers";
import ConditionalInElement from "discourse/components/conditional-in-element";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import trapTab from "discourse/modifiers/trap-tab";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";

const FLASH_TYPES = ["success", "error", "warning", "info"];

export default class DModal extends Component {
  @service modal;
  @tracked wrapperElement;

  @action
  setupListeners(element) {
    document.documentElement.addEventListener(
      "keydown",
      this.handleDocumentKeydown
    );
    this.wrapperElement = element;
  }

  @action
  cleanupListeners() {
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
  handleWrapperClick(e) {
    if (e.button !== 0) {
      return; // Non-default mouse button
    }

    if (!this.dismissable) {
      return;
    }

    return this.args.closeModal?.({
      initiatedBy: CLOSE_INITIATED_BY_CLICK_OUTSIDE,
    });
  }

  @action
  handleDocumentKeydown(event) {
    if (this.args.hidden) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      event.stopPropagation();
      this.args.closeModal({ initiatedBy: CLOSE_INITIATED_BY_ESC });
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
    this.args.closeModal({ initiatedBy: CLOSE_INITIATED_BY_BUTTON });
  }

  @action
  validateFlashType(type) {
    if (type && !FLASH_TYPES.includes(type)) {
      throw `@flashType must be one of ${FLASH_TYPES.join(", ")}`;
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

    return class WrapperComponent extends ClassicComponent {
      tagName = tagName;
    };
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    {{! template-lint-disable no-invalid-interactive }}

    <ConditionalInElement
      @element={{this.modal.containerElement}}
      @inline={{@inline}}
      @append={{true}}
    >
      <this.dynamicElement
        class={{concatClass "modal" "d-modal" (if @inline "-inline")}}
        data-keyboard="false"
        aria-modal="true"
        role="dialog"
        aria-labelledby={{if @title "discourse-modal-title"}}
        ...attributes
        {{didInsert this.setupListeners}}
        {{willDestroy this.cleanupListeners}}
        {{trapTab preventScroll=false}}
      >

        <div class="d-modal__container">
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
            <div class={{concatClass "d-modal__header" @headerClass}}>

              {{yield to="headerAboveTitle"}}

              {{#if @title}}
                <div class="d-modal__title">
                  <h3
                    id="discourse-modal-title"
                    class="d-modal__title-text"
                  >{{@title}}</h3>

                  {{#if @subtitle}}
                    <p class="d-modal__subtitle-text">{{@subtitle}}</p>
                  {{/if}}

                  {{yield to="belowModalTitle"}}
                </div>
              {{/if}}
              {{yield to="headerBelowTitle"}}

              {{#if this.dismissable}}
                <DButton
                  @icon="times"
                  @action={{this.handleCloseButton}}
                  @title="modal.close"
                  class="btn-transparent modal-close"
                />
              {{/if}}
            </div>
          {{/if}}

          {{yield to="belowHeader"}}

          {{this.validateFlashType @flashType}}
          {{#if @flash}}
            <div
              id="modal-alert"
              role="alert"
              class={{concatClass
                "alert"
                (if @flashType (concat "alert-" @flashType))
              }}
            >
              {{~@flash~}}
            </div>
          {{/if}}

          <div class={{concatClass "d-modal__body" @bodyClass}} tabindex="-1">
            {{#if (has-block "body")}}
              {{yield to="body"}}
            {{else}}
              {{yield}}
            {{/if}}
          </div>

          {{#if (has-block "footer")}}
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
          {{on "click" this.handleWrapperClick}}
        ></div>
      {{/unless}}
    </ConditionalInElement>
  </template>
}
