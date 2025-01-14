import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/components/d-page-action-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const HEADLESS_ACTIONS = ["new", "edit"];

export default class DPageHeader extends Component {
  @service site;
  @service router;
  @tracked shouldDisplay = true;

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this, this.#checkIfShouldDisplay);
    this.#checkIfShouldDisplay();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.#checkIfShouldDisplay);
  }

  @bind
  #checkIfShouldDisplay() {
    if (this.args.shouldDisplay !== undefined) {
      return (this.shouldDisplay = this.args.shouldDisplay);
    }

    const currentPath = this.router._router.currentPath;
    if (!currentPath) {
      return (this.shouldDisplay = true);
    }

    // NOTE: This has a little admin-specific logic in it, in future
    // we could extract this out and have it a bit more generic,
    // for now I think it's a fine tradeoff.
    const pathSegments = currentPath.split(".");
    this.shouldDisplay =
      !pathSegments.includes("admin") ||
      !HEADLESS_ACTIONS.find((segment) => pathSegments.includes(segment));
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="d-page-header">
        <div class="d-page-header__breadcrumbs">
          <DBreadcrumbsContainer />
          {{yield to="breadcrumbs"}}
        </div>

        <div class="d-page-header__title-row">
          {{#if @titleLabel}}
            <h1 class="d-page-header__title">{{@titleLabel}}</h1>
          {{/if}}

          {{#if (or (has-block "actions") @headerActionComponent)}}
            <div class="d-page-header__actions">
              {{#if this.site.mobileView}}
                <DMenu
                  @identifier="d-page-header-mobile-actions"
                  @title={{i18n "more_options"}}
                  @icon="ellipsis-vertical"
                  class="btn-small"
                >
                  <:content>
                    <DropdownMenu class="d-page-header__mobile-actions">
                      {{#let
                        (hash
                          Primary=DefaultActionListItem
                          Default=DefaultActionListItem
                          Danger=DangerActionListItem
                          Wrapped=WrappedActionListItem
                        )
                        as |actions|
                      }}
                        {{#if (has-block "actions")}}
                          {{yield actions to="actions"}}
                        {{else}}
                          <@headerActionComponent @actions={{actions}} />
                        {{/if}}
                      {{/let}}
                    </DropdownMenu>
                  </:content>
                </DMenu>
              {{else}}
                {{#let
                  (hash
                    Primary=PrimaryButton
                    Default=DefaultButton
                    Danger=DangerButton
                    Wrapped=WrappedButton
                  )
                  as |actions|
                }}
                  {{#if (has-block "actions")}}
                    {{yield actions to="actions"}}
                  {{else}}
                    <@headerActionComponent @actions={{actions}} />
                  {{/if}}
                {{/let}}
              {{/if}}
            </div>
          {{/if}}
        </div>

        {{#if @descriptionLabel}}
          <p class="d-page-header__description">
            {{htmlSafe @descriptionLabel}}
            {{#if @learnMoreUrl}}
              <span class="d-page-header__learn-more">{{htmlSafe
                  (i18n "learn_more_with_link" url=@learnMoreUrl)
                }}</span>
            {{/if}}
          </p>
        {{/if}}

        {{#unless @hideTabs}}
          <div class="d-nav-submenu">
            <HorizontalOverflowNav class="d-nav-submenu__tabs">
              {{yield to="tabs"}}
            </HorizontalOverflowNav>
          </div>
        {{/unless}}
      </div>
    {{/if}}
  </template>
}
