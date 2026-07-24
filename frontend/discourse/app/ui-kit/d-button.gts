import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

type DButtonActionCallback = (...args: unknown[]) => void;

interface DButtonActionObject {
  value: DButtonActionCallback;
}

type DButtonAction = DButtonActionCallback | DButtonActionObject;

type RouteModel = string | number | object;

interface DButtonSignature {
  Args: {
    // Text
    title?: string;
    translatedTitle?: string;
    label?: string;
    translatedLabel?: string;

    // Actions / events
    action?: DButtonAction;
    actionParam?: unknown;
    forwardEvent?: boolean;
    onKeyDown?: (event: KeyboardEvent) => void;

    // Navigation
    href?: string;
    route?: string;
    routeModels?: RouteModel | RouteModel[];

    // State
    isLoading?: boolean;
    disabled?: boolean;
    preventFocus?: boolean;

    // Display mode
    display?: "link";

    // Display / icon
    icon?: string;
    ellipsis?: boolean;
    suffixIcon?: string;

    // Accessibility
    ariaLabel?: string;
    translatedAriaLabel?: string;
    ariaExpanded?: boolean;
    ariaPressed?: boolean;
    ariaControls?: string;
    ariaHidden?: boolean;

    // HTML attributes
    type?: string;
    id?: string;
    form?: string;
    tabindex?: string;
    class?: string;
  };

  Element: HTMLButtonElement;

  // Optional yield
  Blocks: {
    default: [];
  };
}

export default class DButton extends Component<DButtonSignature> {
  @service router;
  @service capabilities;

  @computed("args.icon")
  get btnIcon() {
    return !isEmpty(this.args?.icon);
  }

  @computed("args.display")
  get btnLink() {
    return this.args?.display === "link";
  }

  @computed("computedLabel")
  get noText() {
    return isEmpty(this.computedLabel);
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
      return trustHTML(i18n(this.args.label));
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
  keyDown(e: KeyboardEvent) {
    if (this.args.onKeyDown) {
      e.stopPropagation();
      this.args.onKeyDown(e);
    } else if (e.key === "Enter") {
      this._triggerAction(e);
    }
  }

  @action
  click(event: MouseEvent) {
    return this._triggerAction(event);
  }

  @action
  mouseDown(event: MouseEvent) {
    if (this.args.preventFocus) {
      event.preventDefault();
    }
  }

  _triggerAction(event: Event) {
    const { action: actionVal, route, routeModels } = this.args;
    const isIOS = this.capabilities?.isIOS;

    if (actionVal || route) {
      if (actionVal) {
        const { actionParam, forwardEvent } = this.args;

        if (typeof actionVal === "object" && actionVal.value) {
          if (isIOS) {
            // Don't optimise INP in iOS
            // it results in focus events not being triggered
            if (forwardEvent) {
              actionVal.value(actionParam, event);
            } else {
              actionVal.value(actionParam);
            }
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
            if (forwardEvent) {
              actionVal(actionParam, event);
            } else {
              actionVal(actionParam);
            }
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
    return dElement(this.args.href ? "a" : "button");
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <this.wrapperElement
      href={{@href}}
      type={{unless @href (or @type "button")}}
      {{! For legacy compatibility. Prefer passing class as attributes. }}
      class={{dConcatClass
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
        {{~dIcon "spinner" class="loading-icon"~}}
      {{else if @icon}}
        {{#if @ariaHidden}}
          <span aria-hidden="true">
            {{~dIcon @icon~}}
          </span>
        {{else}}
          {{~dIcon @icon~}}
        {{/if}}
      {{/if}}

      {{~#if this.computedLabel~}}
        <span class="d-button-label">
          {{~this.computedLabel~}}
          {{~#if @ellipsis~}}
            &hellip;
          {{~/if~}}
        </span>
      {{~else if (has-block)~}}
        {{! Block content provides the label, no spacer needed }}
      {{~else if (or @icon @isLoading)~}}
        <span aria-hidden="true">
          &#8203;
          {{! Zero-width space character, so icon-only button height = regular button height }}
        </span>
      {{~/if~}}

      {{yield}}

      {{#if @suffixIcon}}
        <span class="d-button__suffix-icon">
          {{~dIcon @suffixIcon~}}
        </span>
      {{/if}}
    </this.wrapperElement>
  </template>
}
