import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { bind } from "discourse/lib/decorators";
import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/ui-kit/d-page-action-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const HEADLESS_ACTIONS = ["new", "edit"];

export default class DPageHeader extends Component {
  @service site;
  @service router;

  @tracked compact = false;
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

  get shouldCollapseActionsOnMobile() {
    return this.site.mobileView && this.args.collapseActionsOnMobile !== false;
  }

  @bind
  #checkIfShouldDisplay() {
    // NOTE: This has a little admin-specific logic in it, in future
    // we could extract this out and have it a bit more generic,
    // for now I think it's a fine tradeoff.
    const currentPath = this.router._router.currentPath;
    const pathSegments = currentPath ? currentPath.split(".") : [];
    const isAdminRoute = pathSegments.includes("admin");

    // Admin pages lead with breadcrumbs and tabs; the title stays in the
    // DOM for assistive tech only.
    this.compact = isAdminRoute;

    if (this.args.shouldDisplay !== undefined) {
      return (this.shouldDisplay = this.args.shouldDisplay);
    }

    if (!currentPath) {
      return (this.shouldDisplay = true);
    }

    this.shouldDisplay =
      !isAdminRoute ||
      !HEADLESS_ACTIONS.find((segment) => pathSegments.includes(segment));
  }

  <template>
    {{! Crumbs register with the breadcrumbs service in render order, so they
    stay mounted while the header is hidden to keep their place when it
    reappears. }}
    {{yield to="breadcrumbs"}}

    {{#if this.shouldDisplay}}
      <div
        class={{dConcatClass "d-page-header" (if this.compact "--compact")}}
        ...attributes
      >
        {{#if (has-block "breadcrumbs")}}
          <div class="d-page-header__breadcrumbs">
            <DBreadcrumbsContainer />
          </div>
        {{/if}}

        {{#if
          (or
            (has-block "title")
            @titleLabel
            (has-block "actions")
            @headerActionComponent
          )
        }}
          <div class="d-page-header__title-row">
            {{#if (has-block "title")}}
              <h1
                class={{dConcatClass
                  "d-page-header__title"
                  (if this.compact "sr-only")
                }}
              >
                {{yield to="title"}}
              </h1>
            {{else if @titleLabel}}
              <h1
                class={{dConcatClass
                  "d-page-header__title"
                  (if this.compact "sr-only")
                }}
              >{{@titleLabel}}</h1>
            {{/if}}

            {{#if (or (has-block "actions") @headerActionComponent)}}
              <div class="d-page-header__actions">
                {{#if this.shouldCollapseActionsOnMobile}}
                  <DMenu
                    class="btn-small btn-default"
                    @icon="ellipsis-vertical"
                    @identifier="d-page-header-mobile-actions"
                    @title={{i18n "more_options"}}
                  >
                    <:content>
                      <DDropdownMenu class="d-page-header__mobile-actions">
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
                      </DDropdownMenu>
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
        {{/if}}

        {{#if @descriptionLabel}}
          <p class="d-page-header__description">
            {{trustHTML @descriptionLabel}}
            {{#if @learnMoreUrl}}
              <span class="d-page-header__learn-more">{{trustHTML
                  (i18n "learn_more_with_link" url=@learnMoreUrl)
                }}</span>
            {{/if}}
          </p>
        {{/if}}

        {{#if @showDrawer}}
          <div class="d-page-header__drawer">
            {{yield to="drawer"}}
          </div>
        {{/if}}

        {{#unless @hideTabs}}
          <div class="d-nav-submenu">
            <DHorizontalOverflowNav class="d-nav-submenu__tabs">
              {{yield to="tabs"}}
            </DHorizontalOverflowNav>
          </div>
        {{/unless}}
      </div>
    {{/if}}
  </template>
}
