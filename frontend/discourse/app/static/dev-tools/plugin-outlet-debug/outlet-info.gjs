import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import ArgsTable from "../shared/args-table";
import devToolsState from "../state";

// Outlets matching these patterns will be displayed with an icon only.
// Feel free to add more if it improves the layout.
const SMALL_OUTLETS = [
  /^topic-list-/,
  "before-topic-list-body",
  "after-topic-status",
  /^header-contents/,
  "after-header-panel",
  /^bread-crumbs/,
  /^user-dropdown-notifications/,
  /^user-dropdown-button/,
  "after-breadcrumbs",
];

/**
 * Debug overlay for PluginOutlet components.
 * Shows outlet name badge with a tooltip containing outlet info, args, and GitHub search link.
 *
 * @param {string} outletName - The name of the plugin outlet.
 * @param {Object} [outletArgs] - Arguments passed to the outlet.
 * @param {Object} [deprecatedArgs] - Deprecated arguments created with `deprecatedOutletArgument`.
 */
export default class OutletInfoComponent extends Component {
  static shouldRender() {
    return devToolsState.pluginOutletDebug;
  }

  @tracked partOfWrapper;

  get isBeforeOrAfter() {
    return this.isBefore || this.isAfter;
  }

  get isBefore() {
    return this.args.outletName.includes("__before");
  }

  get isAfter() {
    return this.args.outletName.includes("__after");
  }

  get baseName() {
    return this.args.outletName.split("__")[0];
  }

  get displayName() {
    return this.partOfWrapper ? this.baseName : this.args.outletName;
  }

  @action
  checkIsWrapper(element) {
    const parent = element.parentElement;
    this.partOfWrapper = [
      this.baseName,
      `${this.baseName}__before`,
      `${this.baseName}__after`,
    ].every((name) =>
      parent.querySelector(`:scope > [data-outlet-name="${name}"]`)
    );
  }

  get isWrapper() {
    return this.partOfWrapper && !this.isBeforeOrAfter;
  }

  get isHidden() {
    return this.isWrapper && !this.isBeforeOrAfter;
  }

  get showName() {
    return !SMALL_OUTLETS.some((pattern) =>
      pattern.test ? pattern.test(this.baseName) : pattern === this.baseName
    );
  }

  /**
   * Checks whether this outlet has any args passed to it.
   *
   * @returns {boolean} True if outlet has at least one arg.
   */
  get hasOutletArgs() {
    return (
      (this.args.outletArgs != null &&
        Object.keys(this.args.outletArgs).length > 0) ||
      (this.args.deprecatedArgs != null &&
        Object.keys(this.args.deprecatedArgs).length > 0)
    );
  }

  /**
   * Returns the heading modifier class based on outlet type.
   *
   * @returns {string} The CSS modifier class for the heading.
   */
  get headingModifier() {
    return this.partOfWrapper ? "--wrapper-outlet" : "--plugin-outlet";
  }

  <template>
    <div
      class={{concatClass
        "plugin-outlet-debug"
        (if this.partOfWrapper "--wrapper")
        (if this.isHidden "hidden")
      }}
      {{didInsert this.checkIsWrapper}}
      data-outlet-name={{@outletName}}
    >
      <DTooltip
        @identifier="plugin-outlet-info"
        @interactive={{true}}
        @placement="bottom-start"
        @maxWidth={{600}}
        @triggers={{hash mobile=(array "click") desktop=(array "hover")}}
        @untriggers={{hash mobile=(array "click") desktop=(array "click")}}
      >
        <:trigger>
          <span class="plugin-outlet-debug__badge">
            {{#if this.partOfWrapper}}
              &lt;{{if this.isAfter "/"}}{{if
                this.showName
                this.displayName
              }}&gt;
            {{else}}
              {{icon "plug"}}
              {{if this.showName this.displayName}}
            {{/if}}
          </span>
        </:trigger>
        <:content>
          <div class="outlet-info__wrapper">
            <div
              class={{concatClass "outlet-info__heading" this.headingModifier}}
            >
              <span class="title">
                {{icon "plug"}}
                {{this.displayName}}
                {{#if this.partOfWrapper}}
                  (wrapper)
                {{/if}}
              </span>
              <a
                class="github-link"
                href="https://github.com/search?q=repo%3Adiscourse%2Fdiscourse%20@name=%22{{this.displayName}}%22&type=code"
                target="_blank"
                rel="noopener noreferrer"
                title="Find on GitHub"
              >{{icon "fab-github"}}</a>
            </div>
            <div class="outlet-info__content">
              {{#if this.hasOutletArgs}}
                <div class="outlet-info__section">
                  <div class="outlet-info__section-title">Outlet Args</div>
                  <ArgsTable
                    @args={{@outletArgs}}
                    @deprecatedArgs={{@deprecatedArgs}}
                    @prefix="plugin outlet"
                  />
                </div>
              {{else}}
                <div class="outlet-info__empty">
                  No outlet args passed to this outlet
                </div>
              {{/if}}
            </div>
          </div>
        </:content>
      </DTooltip>
    </div>
    {{yield}}
  </template>
}
