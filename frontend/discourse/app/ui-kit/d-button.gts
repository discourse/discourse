import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import type { CapabilitiesService } from "discourse/services/capabilities";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/** A handler for `@action`, called with the given parameters. */
type DButtonCallback<Params extends unknown[]> = (...params: Params) => void;

/** `@action` as a function, or as an object holding one under `value`. */
type DButtonAction<Params extends unknown[]> =
  | DButtonCallback<Params>
  | { value: DButtonCallback<Params> };

/**
 * `@action` together with `@forwardEvent`. The event reaches the handler only when
 * `@forwardEvent` is true, so a handler that needs it requires the flag. `NoInfer`
 * makes `P` come from `@actionParam` alone, so a handler cannot widen it to a
 * parameter the button never supplies.
 */
type DButtonActionArgs<P> =
  | {
      /** Called on click with `@actionParam`. */
      action?: DButtonAction<[param: NoInfer<P>]>;
      /** Whether `@action` also receives the triggering event. */
      forwardEvent?: false;
    }
  | {
      /** Called on click with `@actionParam` and the triggering event. */
      action?: DButtonAction<[param: NoInfer<P>, event: Event]>;
      /** Whether `@action` also receives the triggering event. */
      forwardEvent: true;
    };

/**
 * Whether the button passes the event to `@action`. Truthiness rather than `=== true`,
 * because callers pass values such as the string `"true"`.
 */
function forwardsEvent<Args extends { forwardEvent?: boolean }>(
  args: Args
): args is Extract<Args, { forwardEvent: true }> {
  return Boolean(args.forwardEvent);
}

type RouteModel = string | number | object;

export interface DButtonSignature<P = undefined> {
  Args: DButtonActionArgs<P> & {
    // Text
    title?: string;
    translatedTitle?: string;
    label?: string;
    translatedLabel?: string;

    // Actions / events
    /** Passed to `@action` as its first argument. */
    actionParam?: P;
    /**
     * Runs `@action` inside the click instead of deferring it, so the handler
     * keeps the click's transient user activation.
     */
    immediate?: boolean;
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

  Element: HTMLButtonElement | HTMLAnchorElement;

  // Optional yield
  Blocks: {
    default: [];
  };
}

export default class DButton<P = undefined> extends Component<
  DButtonSignature<P>
> {
  @service declare router: RouterService;
  @service declare capabilities: CapabilitiesService;

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

  get btnContentClass() {
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

  get wrapperElement() {
    return dElement(this.args.href ? "a" : "button");
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

  /**
   * Binds `@action` to this click: `@actionParam`, plus the event when
   * `@forwardEvent` is set. Returns nothing when `@action` holds no handler.
   * A `{ value }` handler is called as a method when the closure runs, so it
   * keeps its receiver and a `.value` replaced before a deferred run wins.
   */
  #bindAction(event: Event): (() => void) | undefined {
    const args = this.args;
    // Optional only so it can be omitted, which leaves `P` as `undefined`.
    const param = args.actionParam as P;

    if (forwardsEvent(args)) {
      const handler = args.action;
      if (typeof handler === "object" && handler.value) {
        return () => handler.value(param, event);
      }
      if (typeof handler === "function") {
        return () => handler(param, event);
      }
      return;
    }

    const handler = args.action;
    if (typeof handler === "object" && handler.value) {
      return () => handler.value(param);
    }
    if (typeof handler === "function") {
      return () => handler(param);
    }
  }

  _triggerAction(event: Event) {
    const { action: actionVal, route, routeModels } = this.args;

    if (actionVal || route) {
      if (actionVal) {
        const invoke = this.#bindAction(event);

        if (invoke) {
          // `next()` defers the handler so the browser can paint first (INP).
          // Two cases must run inside the dispatch instead: iOS, where the
          // deferral stops focus events firing, and handlers needing the
          // click's transient user activation, which does not survive it.
          if (this.args.immediate || this.capabilities?.isIOS) {
            invoke();
          } else {
            next(invoke);
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

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <this.wrapperElement
      aria-controls={{@ariaControls}}
      aria-expanded={{this.computedAriaExpanded}}
      aria-label={{this.computedAriaLabel}}
      aria-pressed={{this.computedAriaPressed}}
      {{! For legacy compatibility. Prefer passing class as attributes. }}
      class={{dConcatClass
        @class
        (if @isLoading "is-loading")
        (if this.btnLink "btn-link" "btn")
        (if this.noText "no-text")
        this.btnContentClass
      }}
      disabled={{this.isDisabled}}
      form={{@form}}
      href={{@href}}
      {{! For legacy compatibility. Prefer passing these as html attributes. }}
      id={{@id}}
      tabindex={{@tabindex}}
      title={{this.computedTitle}}
      type={{unless @href (or @type "button")}}
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
