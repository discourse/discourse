import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty, equal, notEmpty } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import { i18n } from "discourse-i18n";

export default class DButton extends Component {
  @service router;
  @service capabilities;

  @notEmpty("args.icon") btnIcon;

  @equal("args.display", "link") btnLink;

  @empty("computedLabel") noText;

  get forceDisabled() {
    return !!this.args.isLoading;
  }

  get isDisabled() {
    return this.forceDisabled || this.args.disabled;
  }

  get btnType() {
    if (this.args.icon) {
      return this.computedLabel ? "btn-icon-text" : "btn-icon";
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
      return htmlSafe(i18n(this.args.label));
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
    const isIOS = this.capabilities?.isIOS;

    if (actionVal || route) {
      if (actionVal) {
        const { actionParam, forwardEvent } = this.args;

        if (typeof actionVal === "object" && actionVal.value) {
          if (isIOS) {
            // Don't optimise INP in iOS
            // it results in focus events not being triggered
            forwardEvent
              ? actionVal.value(actionParam, event)
              : actionVal.value(actionParam);
          } else {
            // Using `next()` to optimise INP
            next(() =>
              forwardEvent
                ? actionVal.value(actionParam, event)
                : actionVal.value(actionParam)
            );
          }
        } else if (typeof actionVal === "function") {
          if (isIOS) {
            // Don't optimise INP in iOS
            // it results in focus events not being triggered
            forwardEvent
              ? actionVal(actionParam, event)
              : actionVal(actionParam);
          } else {
            // Using `next()` to optimise INP
            next(() =>
              forwardEvent
                ? actionVal(actionParam, event)
                : actionVal(actionParam)
            );
          }
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
    return element(this.args.href ? "a" : "button");
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <this.wrapperElement
      href={{@href}}
      type={{unless @href (or @type "button")}}
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
          {{~this.computedLabel~}}
          {{~#if @ellipsis~}}
            &hellip;
          {{~/if~}}
        </span>
      {{~else if (or @icon @isLoading)~}}
        <span aria-hidden="true">
          &#8203;
          {{! Zero-width space character, so icon-only button height = regular button height }}
        </span>
      {{~/if~}}

      {{yield}}
    </this.wrapperElement>
  </template>
}
