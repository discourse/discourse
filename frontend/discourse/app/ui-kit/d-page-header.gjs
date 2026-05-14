// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
/** @type {import("discourse/float-kit/components/d-menu.gjs")} */
import DMenu from "discourse/float-kit/components/d-menu";
import { or } from "discourse/truth-helpers";
/** @type {import("discourse/ui-kit/d-breadcrumbs-container.gjs")} */
import DBreadcrumbsContainer from "discourse/ui-kit/d-breadcrumbs-container";
/** @type {import("discourse/ui-kit/d-dropdown-menu.gjs")} */
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
/** @type {import("discourse/ui-kit/d-horizontal-overflow-nav.gjs")} */
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
/** @type {import("discourse/ui-kit/d-page-action-button.gjs")} */
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/ui-kit/d-page-action-button";
import { i18n } from "discourse-i18n";

const HEADLESS_ACTIONS = ["new", "edit"];

/**
 * The top-of-page header used across admin and account pages. Combines
 * breadcrumbs, a title, a description with optional "learn more" link, a
 * drawer slot, action buttons (collapsible to a dropdown on mobile), and a
 * row of nav tabs. Use this as the standard page header rather than
 * hand-rolling each section so spacing, typography, and the breakpoint
 * collapse behavior stay consistent.
 *
 * The header auto-hides itself on certain admin sub-routes (the "new" and
 * "edit" sub-pages, which already have their own headers). Pass
 * `@shouldDisplay` explicitly to override this heuristic in either direction.
 *
 * Action buttons come from either a `<:actions>` named block (recommended) or
 * an out-of-line `@headerActionComponent` reference. Both receive the same
 * `actions` hash with `Primary`, `Default`, `Danger`, and `Wrapped`
 * sub-components that adapt to viewport.
 *
 * @example
 * <DPageHeader @titleLabel={{i18n "admin.badges.title"}}>
 *   <:breadcrumbs>
 *     <DBreadcrumbsItem @path="/admin/badges" @label="Badges" />
 *   </:breadcrumbs>
 *   <:actions as |actions|>
 *     <actions.Primary @route="adminBadges.show" @routeModels="new" @label="New badge" />
 *   </:actions>
 *   <:tabs>
 *     <DNavItem @route="adminBadges.index" @label="All" />
 *   </:tabs>
 * </DPageHeader>
 */

/**
 * @typedef DPageHeaderActions
 * @property {typeof PrimaryButton} Primary Renders as a primary action button on desktop, default dropdown list item on mobile.
 * @property {typeof DefaultButton} Default Renders as a default action button on desktop, default dropdown list item on mobile.
 * @property {typeof DangerButton} Danger Renders as a danger-styled button on desktop, danger dropdown list item on mobile.
 * @property {typeof WrappedButton} Wrapped Renders arbitrary inline content as an action slot on desktop, wrapped dropdown list item on mobile.
 */

/**
 * @typedef DPageHeaderSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.titleLabel] Translated text for the page title. Used when no `<:title>` block is provided.
 * @property {string} [Args.descriptionLabel] Translated description rendered below the title. Passed through `trustHTML` — make sure the source is already-safe HTML (typically an `i18n()` call).
 * @property {string} [Args.learnMoreUrl] URL appended after `@descriptionLabel` as a "Learn more…" link.
 * @property {boolean} [Args.shouldDisplay] Forces the header on or off, overriding the route-aware default. Omit to let the component auto-hide on admin sub-routes that have their own header (the "new" and "edit" detail pages).
 * @property {boolean} [Args.collapseActionsOnMobile] Whether action buttons should collapse into a mobile dropdown. Defaults to `true`.
 * @property {unknown} [Args.headerActionComponent] Out-of-line component reference rendered in the actions slot, used when a `<:actions>` named block is impractical. Receives `@actions` (the same hash the named block yields).
 * @property {boolean} [Args.showDrawer] Renders the `<:drawer>` named block region. Defaults to off.
 * @property {boolean} [Args.hideTabs] Suppresses the tab strip even when the `<:tabs>` block has content. Defaults to off.
 *
 * @property {HTMLDivElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.breadcrumbs Optional breadcrumb items rendered after the base breadcrumb. Typically a list of `<DBreadcrumbsItem>`.
 * @property {[]} Blocks.title Custom title content. Wins over `@titleLabel` when both are provided.
 * @property {[DPageHeaderActions]} Blocks.actions Yields the action-button hash. The component types adapt to viewport.
 * @property {[]} Blocks.drawer Optional drawer content (e.g. filters, batch controls). Requires `@showDrawer={{true}}`.
 * @property {[]} Blocks.tabs Optional nav-tab content (typically a list of `<DNavItem>`).
 */

/** @extends {Component<DPageHeaderSignature>} */
export default class DPageHeader extends Component {
  @service site;
  @service router;

  @tracked shouldDisplay = true;

  constructor(owner, args) {
    super(owner, args);
    this.router.on("routeDidChange", this, this.#checkIfShouldDisplay);
    this.#checkIfShouldDisplay();
  }

  willDestroy() {
    // @ts-expect-error canonical Ember pattern; `arguments` is `IArguments` and not a spreadable tuple
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.#checkIfShouldDisplay);
  }

  #checkIfShouldDisplay() {
    if (this.args.shouldDisplay !== undefined) {
      return (this.shouldDisplay = this.args.shouldDisplay);
    }

    const currentPath = this.router._router.currentPath;
    if (!currentPath) {
      return (this.shouldDisplay = true);
    }

    // Admin-specific heuristic: hide the page header on `new` and `edit`
    // sub-routes since those pages render their own header. Could be
    // extracted later if other route trees need similar logic.
    const pathSegments = currentPath.split(".");
    this.shouldDisplay =
      !pathSegments.includes("admin") ||
      !HEADLESS_ACTIONS.find((segment) => pathSegments.includes(segment));
  }

  get shouldCollapseActionsOnMobile() {
    return this.site.mobileView && this.args.collapseActionsOnMobile !== false;
  }

  <template>
    {{! @glint-nocheck: DMenu's curried trigger and the dynamic action-component hash both surface unknown-element complaints }}
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
                    @identifier="d-page-header-mobile-actions"
                    @title={{i18n "more_options"}}
                    @icon="ellipsis-vertical"
                    class="btn-small btn-default"
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
