import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import type Evented from "@ember/object/evented";
import type Owner from "@ember/owner";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import type { ComponentLike } from "@glint/template";
import DMenu from "discourse/float-kit/components/d-menu";
import type Site from "discourse/models/site";
import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  type DPageActions,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/ui-kit/d-page-action-button";
import { i18n } from "discourse-i18n";

const HEADLESS_ACTIONS = ["new", "edit"];

interface DPageHeaderSignature {
  Args: {
    /** The title, when there is no `title` block. */
    titleLabel?: string;

    /** A description shown under the title. Its markup is rendered. */
    descriptionLabel?: string;

    /** A URL linked after the description. */
    learnMoreUrl?: string;

    /** Whether to render the `drawer` block. */
    showDrawer?: boolean;

    /** Whether to hide the tabs. */
    hideTabs?: boolean;

    /**
     * Whether to show the header. Without it, the header hides on admin pages
     * that create or edit a record.
     */
    shouldDisplay?: boolean;

    /** Whether to collapse the actions into a menu on mobile. Defaults to `true`. */
    collapseActionsOnMobile?: boolean;

    /** A component rendered with the actions, when there is no `actions` block. */
    headerActionComponent?: ComponentLike<{ Args: { actions: DPageActions } }>;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** Breadcrumbs added after the base ones. */
    breadcrumbs: [];

    /** The title. */
    title: [];

    /** The page actions. */
    actions: [actions: DPageActions];

    /** Content shown in a drawer under the description. */
    drawer: [];

    /** The navigation tabs. */
    tabs: [];
  };
}

export default class DPageHeader extends Component<DPageHeaderSignature> {
  @service declare site: Site;
  @service declare router: RouterService;

  @tracked shouldDisplay = true;

  constructor(owner: Owner, args: DPageHeaderSignature["Args"]) {
    super(owner, args);
    // TODO(typescript-pending): the router service types only the two-argument `on`;
    // remove the cast when it declares the target form `Evented` supports.
    (this.router as unknown as Evented).on(
      "routeDidChange",
      this,
      this.#checkIfShouldDisplay
    );
    this.#checkIfShouldDisplay();
  }

  willDestroy() {
    super.willDestroy();
    this.router.off("routeDidChange", this, this.#checkIfShouldDisplay);
  }

  get shouldCollapseActionsOnMobile() {
    return this.site.mobileView && this.args.collapseActionsOnMobile !== false;
  }

  #checkIfShouldDisplay() {
    if (this.args.shouldDisplay !== undefined) {
      return (this.shouldDisplay = this.args.shouldDisplay);
    }

    // TODO(typescript-pending): the private router has no public type; remove the cast
    // when the current path comes from a public API.
    const currentPath = (
      this.router as unknown as { _router: { currentPath?: string } }
    )._router.currentPath;
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
      <div class="d-page-header" ...attributes>
        {{#if (has-block "breadcrumbs")}}
          <div class="d-page-header__breadcrumbs">
            <DBreadcrumbsContainer />
            {{yield to="breadcrumbs"}}
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
              <h1 class="d-page-header__title">
                {{yield to="title"}}
              </h1>
            {{else if @titleLabel}}
              <h1 class="d-page-header__title">{{@titleLabel}}</h1>
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
