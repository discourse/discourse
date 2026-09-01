import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { and, eq, not, or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SectionLinkPrefix from "./section-link-prefix";

/**
 * Checks if a given string is a valid color hex code.
 *
 * @param {String|undefined} input Input string to check if it is a valid color hex code. Can be in the form of "FFFFFF" or "#FFFFFF" or "FFF" or "#FFF".
 * @returns {String|undefined} Returns the matching color hex code without the leading `#` if it is valid, otherwise returns undefined. Example: "FFFFFF" or "FFF".
 */
export function isHex(input) {
  const match = input?.match(/^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/);

  if (match) {
    return match[1];
  } else {
    return;
  }
}

/**
 * Sidebar section link component.
 *
 * @component SectionLink
 * @param {Component} @contentComponent - Component to render inside the link text span (gets ellipsized)
 * @param {Component} @suffixComponent - Component to render after the link text (stays visible, not ellipsized)
 * @param {Object} @suffixArgs - Arguments to pass to the suffix component
 */
export default class SectionLink extends Component {
  @service capabilities;
  @service currentUser;

  @tracked hovering = false;
  @tracked hoverActionActive = false;

  constructor() {
    super(...arguments);
    this.args.didInsert?.();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.args.willDestroy?.();
  }

  get shouldDisplay() {
    if (this.args.shouldDisplay === undefined) {
      return true;
    }

    return this.args.shouldDisplay;
  }

  get wrapperClass() {
    let classNames = ["sidebar-section-link-wrapper"];

    if (this.hovering || this.hoverActionActive) {
      classNames.push("--hovering");
    }

    return classNames.join(" ");
  }

  get linkClass() {
    let classNames = ["sidebar-section-link", "sidebar-row"];

    if (this.args.linkClass) {
      classNames.push(this.args.linkClass);
    }

    if (this.args.class) {
      deprecated("SectionLink's @class arg has been renamed to @linkClass", {
        id: "discourse.section-link-class-arg",
        since: "3.2.0.beta4",
      });
      classNames.push(this.args.class);
    }

    if (this.args.href && this.args.href === this.args.exactUrlMatch?.value) {
      classNames.push("exact-url-match");
    }

    if (
      this.args.href &&
      typeof this.args.currentWhen === "boolean" &&
      this.args.currentWhen
    ) {
      classNames.push("active");
    }

    return classNames.join(" ");
  }

  get target() {
    return this.currentUser?.user_option?.external_links_in_new_tab &&
      this.isExternal
      ? "_blank"
      : "_self";
  }

  get isExternal() {
    return (
      this.args.href &&
      new URL(this.args.href, window.location.href).origin !==
        window.location.origin
    );
  }

  get models() {
    if (this.args.model) {
      return [this.args.model];
    }

    if (this.args.models) {
      return this.args.models;
    }

    return [];
  }

  get prefixColor() {
    const hexCode = isHex(this.args.prefixColor);

    if (hexCode) {
      return `#${hexCode}`;
    } else {
      return;
    }
  }

  get shouldRenderHoverAction() {
    if (!this.args.hoverValue) {
      return false;
    }

    // on narrow touch layouts the affordance exists elsewhere; rendering
    // the button would only clutter the panel
    return !this.capabilities.touch || this.capabilities.viewport.sm;
  }

  @action
  hoveringSectionLink() {
    if (this.capabilities.touch || this.hoverActionActive) {
      return;
    }
    this.hovering = true;
  }

  @action
  stopHoveringSectionLink() {
    if (this.capabilities.touch || this.hoverActionActive) {
      return;
    }
    this.hovering = false;
  }

  @action
  runHoverAction(event) {
    this.hoverActionActive = true;
    this.args.hoverAction(event, () => {
      this.hoverActionActive = false;
      this.hovering = false;
    });
  }

  @bind
  maybeScrollIntoView(element) {
    if (!this.args.scrollIntoView) {
      return;
    }

    schedule("afterRender", () => {
      if (isFullyScrolledIntoView(element)) {
        return;
      }

      element.scrollIntoView({
        block: "nearest",
        inline: "nearest",
      });
    });
  }

  <template>
    {{#if this.shouldDisplay}}
      <li
        class={{this.wrapperClass}}
        data-list-item-name={{@linkName}}
        ...attributes
        {{didInsert this.maybeScrollIntoView}}
        {{didUpdate this.maybeScrollIntoView @scrollIntoView}}
        {{on "mouseenter" this.hoveringSectionLink}}
        {{on "mouseleave" this.stopHoveringSectionLink}}
      >
        {{#if @href}}
          <a
            class={{this.linkClass}}
            data-link-name={{@linkName}}
            draggable={{if @suppressNativeDrag false}}
            href={{@href}}
            rel="noopener noreferrer"
            target={{this.target}}
            title={{@title}}
          >
            <SectionLinkPrefix
              @prefixBadge={{@prefixBadge}}
              @prefixColor={{this.prefixColor}}
              @prefixCSSClass={{@prefixCSSClass}}
              @prefixType={{@prefixType}}
              @prefixValue={{@prefixValue}}
            />

            <span
              class={{dConcatClass
                "sidebar-section-link-content-text"
                @contentCSSClass
              }}
            >
              {{@content}}
              <@contentComponent />
            </span>

            {{#if @badgeText}}
              <span class="sidebar-section-link-content-badge">
                {{@badgeText}}
              </span>
            {{/if}}

            {{#if @suffixComponent}}
              <@suffixComponent @suffixArgs={{@suffixArgs}} />
            {{/if}}

            {{#if @suffixValue}}
              <span
                class={{dConcatClass
                  "sidebar-section-link-suffix"
                  @suffixType
                  @suffixCSSClass
                }}
              >
                {{#if (eq @suffixType "icon")}}
                  {{dIcon @suffixValue}}
                {{/if}}
              </span>
            {{/if}}

            {{! eslint-disable ember/template-no-nested-interactive }}
            {{#if this.shouldRenderHoverAction}}
              <span class="sidebar-section-link-hover">
                <button
                  aria-label={{@hoverTitle}}
                  class="sidebar-section-hover-button btn-flat"
                  title={{@hoverTitle}}
                  type="button"
                  {{on "click" this.runHoverAction}}
                >
                  {{#if (eq @hoverType "icon")}}
                    {{dIcon @hoverValue class="hover-icon"}}
                  {{/if}}
                </button>
              </span>
            {{/if}}
          </a>
        {{else}}
          <LinkTo
            class={{this.linkClass}}
            data-link-name={{@linkName}}
            draggable={{if @suppressNativeDrag false}}
            title={{@title}}
            @current-when={{and (not @exactUrlMatch) @currentWhen}}
            @models={{this.models}}
            @query={{or @query (hash)}}
            @route={{@route}}
          >
            <SectionLinkPrefix
              @prefixBadge={{@prefixBadge}}
              @prefixColor={{this.prefixColor}}
              @prefixCSSClass={{@prefixCSSClass}}
              @prefixType={{@prefixType}}
              @prefixValue={{@prefixValue}}
            />

            <span
              class={{dConcatClass
                "sidebar-section-link-content-text"
                @contentCSSClass
              }}
            >
              {{@content}}
              <@contentComponent />
            </span>

            {{#if @badgeText}}
              <span class="sidebar-section-link-content-badge">
                {{@badgeText}}
              </span>
            {{/if}}

            {{#if @suffixComponent}}
              <@suffixComponent @suffixArgs={{@suffixArgs}} />
            {{/if}}

            {{#if @suffixValue}}
              <span
                class={{dConcatClass
                  "sidebar-section-link-suffix"
                  @suffixType
                  @suffixCSSClass
                }}
              >
                {{#if (eq @suffixType "icon")}}
                  {{dIcon @suffixValue}}
                {{/if}}
              </span>
            {{/if}}

            {{#if this.shouldRenderHoverAction}}
              <span class="sidebar-section-link-hover">
                <button
                  aria-label={{@hoverTitle}}
                  class="sidebar-section-hover-button btn-flat"
                  title={{@hoverTitle}}
                  type="button"
                  {{on "click" this.runHoverAction}}
                >
                  {{#if (eq @hoverType "icon")}}
                    {{dIcon @hoverValue class="hover-icon"}}
                  {{/if}}
                </button>
              </span>
            {{/if}}
          </LinkTo>
        {{/if}}
      </li>
    {{/if}}
  </template>
}

function isFullyScrolledIntoView(element) {
  const rect = element.getBoundingClientRect();
  let node = element.parentElement;
  let scrolled = false;

  while (node && node !== document.body) {
    const { overflowY } = getComputedStyle(node);

    if (
      (overflowY === "auto" || overflowY === "scroll") &&
      node.scrollHeight > node.clientHeight
    ) {
      scrolled = true;
      const bounds = node.getBoundingClientRect();

      if (rect.top < bounds.top || rect.bottom > bounds.bottom) {
        return false;
      }
    }

    node = node.parentElement;
  }

  if (scrolled) {
    return true;
  }

  return rect.top >= 0 && rect.bottom <= window.innerHeight;
}
