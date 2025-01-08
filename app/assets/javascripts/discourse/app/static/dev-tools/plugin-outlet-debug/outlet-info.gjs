import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import DTooltip from "float-kit/components/d-tooltip";
import devToolsState from "../state";
import ArgsTable from "./args-table";

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

  <template>
    <div
      class={{concatClass
        "plugin-outlet-info"
        (if this.partOfWrapper "--wrapper")
        (if this.isHidden "hidden")
      }}
      {{didInsert this.checkIsWrapper}}
      data-outlet-name={{@outletName}}
      title={{@outletName}}
    >
      <DTooltip
        @maxWidth={{600}}
        @triggers={{hash mobile=(array "click") desktop=(array "hover")}}
        @untriggers={{hash mobile=(array "click") desktop=(array "click")}}
        @identifier="plugin-outlet-info"
      >
        <:trigger>
          <span class="name">
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
          <div class="plugin-outlet-info__wrapper">
            <div class="plugin-outlet-info__heading">
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
            <div class="plugin-outlet-info__content">
              <ArgsTable @outletArgs={{@outletArgs}} />
            </div>
          </div>
        </:content>
      </DTooltip>
    </div>
    {{yield}}
  </template>
}
