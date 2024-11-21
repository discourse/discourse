import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty, equal, notEmpty } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import GlimmerComponentWithDeprecatedParentView from "discourse/components/glimmer-component-with-deprecated-parent-view";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import deprecated from "discourse-common/lib/deprecated";
import { i18n } from "discourse-i18n";

const ACTION_AS_STRING_DEPRECATION_ARGS = [
  "DButton no longer supports @action as a string. Please refactor to use an closure action instead.",
  { id: "discourse.d-button-action-string" },
];

export default class DButton extends GlimmerComponentWithDeprecatedParentView {
  @service router;

  @notEmpty("args.icon") btnIcon;

  @equal("args.display", "link") btnLink;

  @empty("computedLabel") noText;

  constructor() {
    super(...arguments);
    if (typeof this.args.action === "string") {
      deprecated(...ACTION_AS_STRING_DEPRECATION_ARGS);
    }
  }

  get forceDisabled() {
    return !!this.args.isLoading;
  }

  get isDisabled() {
    return this.forceDisabled || this.args.disabled;
  }

  get btnType() {
    if (this.args.icon) {
      return this.computedLabel ? "btn-icon-text" : "btn-icon";
    } else if (this.computedLabel) {
      return "btn-text";
    }
  }

  get computedTitle() {
    if (this.args.title) {
      return i18n(this.args.title);
    }
    return this.args.translatedTitle;
  }

  get computedLabel() {
    if (this.args.label) {
      return i18n(this.args.label);
    }
    return this.args.translatedLabel;
  }

  get computedAriaLabel() {
    if (this.args.ariaLabel) {
      return i18n(this.args.ariaLabel);
    }
    if (this.args.translatedAriaLabel) {
      return this.args.translatedAriaLabel;
    }
  }

  get computedAriaExpanded() {
    if (this.args.ariaExpanded === true) {
      return "true";
    }
    if (this.args.ariaExpanded === false) {
      return "false";
    }
  }

  get computedAriaPressed() {
    if (this.args.ariaPressed === true) {
      return "true";
    }
    if (this.args.ariaPressed === false) {
      return "false";
    }
  }

  @action
  keyDown(e) {
    if (this.args.onKeyDown) {
      e.stopPropagation();
      this.args.onKeyDown(e);
    } else if (e.key === "Enter") {
      this._triggerAction(e);
    }
  }

  @action
  click(event) {
    return this._triggerAction(event);
  }

  @action
  mouseDown(event) {
    if (this.args.preventFocus) {
      event.preventDefault();
    }
  }

  _triggerAction(event) {
    const { action: actionVal, route, routeModels } = this.args;

    if (actionVal || route) {
      if (actionVal) {
        const { actionParam, forwardEvent } = this.args;

        if (typeof actionVal === "string") {
          deprecated(...ACTION_AS_STRING_DEPRECATION_ARGS);
          if (this._target?.send) {
            this._target.send(actionVal, actionParam);
          } else {
            throw new Error(
              "DButton could not find a target for the action. Use a closure action instead"
            );
          }
        } else if (typeof actionVal === "object" && actionVal.value) {
          // Using `next()` to optimise INP
          next(() =>
            forwardEvent
              ? actionVal.value(actionParam, event)
              : actionVal.value(actionParam)
          );
        } else if (typeof actionVal === "function") {
          // Using `next()` to optimise INP
          next(() =>
            forwardEvent
              ? actionVal(actionParam, event)
              : actionVal(actionParam)
          );
        }
      } else if (route) {
        if (routeModels) {
          const routeModelsArray = Array.isArray(routeModels)
            ? routeModels
            : [routeModels];
          this.router.transitionTo(route, ...routeModelsArray);
        } else {
          this.router.transitionTo(route);
        }
      }

      event.preventDefault();
      event.stopPropagation();

      return false;
    }
  }

  get wrapperElement() {
    const { href, type } = this.args;

    return href
      ? <template><a href={{href}} ...attributes>{{yield}}</a></template>
      : <template>
          <button type={{or type "button"}} ...attributes>{{yield}}</button>
        </template>;
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <this.wrapperElement
      {{! For legacy compatibility. Prefer passing class as attributes. }}
      class={{concatClass
        @class
        (if @isLoading "is-loading")
        (if this.btnLink "btn-link" "btn")
        (if this.noText "no-text")
        this.btnType
      }}
      {{! For legacy compatibility. Prefer passing these as html attributes. }}
      id={{@id}}
      form={{@form}}
      aria-controls={{@ariaControls}}
      aria-expanded={{this.computedAriaExpanded}}
      aria-pressed={{this.computedAriaPressed}}
      tabindex={{@tabindex}}
      disabled={{this.isDisabled}}
      title={{this.computedTitle}}
      aria-label={{this.computedAriaLabel}}
      ...attributes
      {{on "keydown" this.keyDown}}
      {{on "click" this.click}}
      {{on "mousedown" this.mouseDown}}
    >
      {{#if @isLoading}}
        {{~icon "spinner" class="loading-icon"~}}
      {{else if @icon}}
        {{#if @ariaHidden}}
          <span aria-hidden="true">
            {{~icon @icon~}}
          </span>
        {{else}}
          {{~icon @icon~}}
        {{/if}}
      {{/if}}

      {{~#if this.computedLabel~}}
        <span class="d-button-label">
          {{~htmlSafe this.computedLabel~}}
          {{~#if @ellipsis~}}
            &hellip;
          {{~/if~}}
        </span>
      {{~else if (or @icon @isLoading)~}}
        &#8203;
        {{! Zero-width space character, so icon-only button height = regular button height }}
      {{~/if~}}

      {{yield}}
    </this.wrapperElement>
  </template>
}
