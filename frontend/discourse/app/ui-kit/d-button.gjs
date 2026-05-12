// @ts-check
import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
/** @type {import("discourse/ui-kit/helpers/d-element.gjs").default} */
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BUTTON_TYPES = ["button", "submit", "reset"];

/**
 * A primary clickable element. Renders a native `<button>` by default, or an
 * `<a>` when `@href` is provided. Supports i18n-keyed labels (`@label`,
 * `@title`, `@ariaLabel`) and already-translated counterparts. Reach for
 * `DButton` instead of writing `<button class="btn">` so loading, disabled,
 * icon, and accessibility states stay consistent across the app.
 *
 * Click behavior comes from exactly one of `@action`, `@route`, or `@href` —
 * passing more than one is a contract violation. `@action` runs inside `next()`
 * on non-iOS to optimise INP; pass `@forwardEvent` if your handler needs the
 * original event.
 *
 * @example
 * <DButton @icon="plus" @label="topic.create" @action={{this.create}} />
 *
 * @example
 * <DButton @href="https://example.com" @translatedLabel="Open" />
 */

/**
 * @typedef DButtonSignature
 *
 * @property {object} Args
 *
 * Text
 *
 * @property {string} [Args.label] Translatable i18n key for the visible label. Mutually exclusive with `translatedLabel`.
 * @property {string} [Args.translatedLabel] Pre-translated visible label. Use when the label is computed at runtime and already localized.
 * @property {string} [Args.title] Translatable i18n key for the native `title` tooltip. Mutually exclusive with `translatedTitle`.
 * @property {string} [Args.translatedTitle] Pre-translated `title` tooltip.
 *
 * Actions and navigation
 *
 * @property {Function|{value: Function}} [Args.action] Click handler. Accepts a plain function or an Ember action descriptor (`{ value: Function }`). Mutually exclusive with `@route` and `@href`.
 * @property {any} [Args.actionParam] Value passed as the first argument to `@action` when it fires.
 * @property {boolean} [Args.forwardEvent] When true, the original click event is passed as the second argument to `@action`.
 * @property {(event: KeyboardEvent) => void} [Args.onKeyDown] Custom keydown handler. When set, the default Enter-triggers-click behavior is suppressed and your handler receives every keydown.
 * @property {string} [Args.href] Renders an `<a href="...">` instead of `<button>`. Use for true links (external URLs, anchor jumps). Mutually exclusive with `@action` and `@route`.
 * @property {string} [Args.route] Ember route name to transition to on click. Mutually exclusive with `@action` and `@href`.
 * @property {object|object[]} [Args.routeModels] Models passed to `router.transitionTo` alongside `@route`. Accepts a single model or an array.
 *
 * State
 *
 * @property {boolean} [Args.isLoading] When true, shows a spinner icon and disables the button. Use for async actions to give the user feedback during the in-flight request.
 * @property {boolean} [Args.disabled] When true, the button is rendered disabled and click handlers do not fire.
 * @property {boolean} [Args.preventFocus] When true, the button does not receive focus on mousedown. Useful for toolbar buttons that should not steal focus from an active editor.
 *
 * Display
 *
 * @property {"link"} [Args.display] Visual style. `"link"` renders as a `.btn-link` (text-only, no background). Omit for the default `.btn` style.
 * @property {string} [Args.icon] Name of the FontAwesome icon to render before the label. Looked up via `discourse/ui-kit/helpers/d-icon`.
 * @property {string} [Args.suffixIcon] Name of an additional icon rendered after the label.
 * @property {boolean} [Args.ellipsis] When true, appends `…` after the label to indicate the click will open a dialog or further interaction.
 *
 * Accessibility
 *
 * @property {string} [Args.ariaLabel] Translatable i18n key for `aria-label`. Required when the button is icon-only. Mutually exclusive with `translatedAriaLabel`.
 * @property {string} [Args.translatedAriaLabel] Pre-translated `aria-label`.
 * @property {boolean} [Args.ariaExpanded] Value for `aria-expanded`. Pass a boolean; the component renders the string `"true"`/`"false"`.
 * @property {boolean} [Args.ariaPressed] Value for `aria-pressed` (toggle-button state).
 * @property {string} [Args.ariaControls] Value for `aria-controls`: the id of the element this button controls.
 * @property {boolean} [Args.ariaHidden] When true, wraps the icon in an `aria-hidden="true"` span so screen readers skip it. Use when the icon is decorative and duplicates the label.
 *
 * HTML attributes (legacy — prefer `...attributes`)
 *
 * @property {"button"|"submit"|"reset"} [Args.type] Native `<button type>` value. Defaults to `"button"` so clicks never accidentally submit a form. Ignored when `@href` is set.
 * @property {string} [Args.id] **Deprecated** — pass `id` via `...attributes` instead. Native `id` attribute.
 * @property {string} [Args.form] **Deprecated** — pass `form` via `...attributes` instead. Native `form` attribute. Associates the button with a form by id when it lives outside that form's DOM.
 * @property {string|number} [Args.tabindex] **Deprecated** — pass `tabindex` via `...attributes` instead. Native `tabindex` attribute.
 * @property {string} [Args.class] **Deprecated** — pass `class` via `...attributes` instead. Extra classes joined to the component's own.
 *
 * @property {HTMLButtonElement} Element The rendered root. When `@href` is set the actual element is an `HTMLAnchorElement`, but the Signature tracks the more common case for `...attributes` typing.
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Optional inner content. When provided alongside `@label`, the label still renders first; pure block content (no `@label`) substitutes for the label entirely.
 */

/** @extends {Component<DButtonSignature>} */
export default class DButton extends Component {
  @service router;
  @service capabilities;

  constructor(owner, args) {
    super(owner, args);

    assert(
      "[d-button] pass either @label or @translatedLabel, not both",
      !(args.label && args.translatedLabel)
    );
    assert(
      "[d-button] pass either @title or @translatedTitle, not both",
      !(args.title && args.translatedTitle)
    );
    assert(
      "[d-button] pass either @ariaLabel or @translatedAriaLabel, not both",
      !(args.ariaLabel && args.translatedAriaLabel)
    );
    assert(
      "[d-button] @action, @route, and @href are mutually exclusive — pick one",
      [args.action, args.route, args.href].filter(Boolean).length <= 1
    );
    assert(
      `[d-button] @type must be one of ${BUTTON_TYPES.join(", ")}`,
      !args.type || BUTTON_TYPES.includes(args.type)
    );
  }

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
            // iOS skips the next() optimisation: scheduling the call breaks
            // focus events that depend on the click being synchronous.
            forwardEvent
              ? actionVal.value(actionParam, event)
              : actionVal.value(actionParam);
          } else {
            // Defer the call to optimise INP — keeps the click handler short
            // so the browser can paint sooner.
            next(() =>
              forwardEvent
                ? actionVal.value(actionParam, event)
                : actionVal.value(actionParam)
            );
          }
        } else if (typeof actionVal === "function") {
          if (isIOS) {
            forwardEvent
              ? actionVal(actionParam, event)
              : actionVal(actionParam);
          } else {
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
    {{! template-lint-disable no-pointer-down-event-binding }}
    {{! @glint-nocheck: dynamic `<this.wrapperElement>` root types the element as `unknown`, which interferes with attribute checks }}
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
