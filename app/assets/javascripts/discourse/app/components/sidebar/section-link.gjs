import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, or } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
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
export default class SectionLink extends Component {
  @service currentUser;

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

  get linkClass() {
    let classNames = ["sidebar-section-link", "sidebar-row"];

    if (this.args.linkClass) {
      classNames.push(this.args.linkClass);
    }

    if (this.args.class) {
      deprecated("SectionLink's @class arg has been renamed to @linkClass", {
        id: "discourse.section-link-class-arg",
        since: "3.2.0.beta4",
        dropFrom: "3.3.0.beta1",
      });
      classNames.push(this.args.class);
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

  @bind
  maybeScrollIntoView(element) {
    if (!this.args.scrollIntoView) {
      return;
    }

    schedule("afterRender", () => {
      const rect = element.getBoundingClientRect();
      const alreadyVisible = rect.top <= window.innerHeight && rect.bottom >= 0;
      if (alreadyVisible) {
        return;
      }

      element.scrollIntoView({
        block: "center",
      });
    });
  }

  <template>
    {{#if this.shouldDisplay}}
      <li
        {{didInsert this.maybeScrollIntoView}}
        {{didUpdate this.maybeScrollIntoView @scrollIntoView}}
        data-list-item-name={{@linkName}}
        class="sidebar-section-link-wrapper"
        ...attributes
      >
        {{#if @href}}
          <a
            href={{@href}}
            rel="noopener noreferrer"
            target={{this.target}}
            title={{@title}}
            data-link-name={{@linkName}}
            class={{this.linkClass}}
          >
            <SectionLinkPrefix
              @prefixType={{@prefixType}}
              @prefixValue={{@prefixValue}}
              @prefixCSSClass={{@prefixCSSClass}}
              @prefixColor={{this.prefixColor}}
              @prefixBadge={{@prefixBadge}}
            />

            <span class="sidebar-section-link-content-text">
              {{@content}}
            </span>
          </a>
        {{else}}
          <LinkTo
            @route={{@route}}
            @query={{or @query (hash)}}
            @models={{this.models}}
            @current-when={{@currentWhen}}
            title={{@title}}
            data-link-name={{@linkName}}
            class={{this.linkClass}}
          >
            <SectionLinkPrefix
              @prefixType={{@prefixType}}
              @prefixValue={{@prefixValue}}
              @prefixCSSClass={{@prefixCSSClass}}
              @prefixColor={{this.prefixColor}}
              @prefixBadge={{@prefixBadge}}
            />

            <span
              class={{concatClass
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

            {{#if @suffixValue}}
              <span
                class={{concatClass
                  "sidebar-section-link-suffix"
                  @suffixType
                  @suffixCSSClass
                }}
              >
                {{#if (eq @suffixType "icon")}}
                  {{icon @suffixValue}}
                {{/if}}
              </span>
            {{/if}}

            {{#if @hoverValue}}
              <span class="sidebar-section-link-hover">
                <button
                  {{on "click" @hoverAction}}
                  type="button"
                  title={{@hoverTitle}}
                  class="sidebar-section-hover-button"
                >
                  {{#if (eq @hoverType "icon")}}
                    {{icon @hoverValue class="hover-icon"}}
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
