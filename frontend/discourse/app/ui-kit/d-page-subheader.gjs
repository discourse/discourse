// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
/** @type {import("discourse/float-kit/components/d-menu.gjs")} */
import DMenu from "discourse/float-kit/components/d-menu";
/** @type {import("discourse/ui-kit/d-dropdown-menu.gjs")} */
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
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

/**
 * The section header that appears below a `DPageHeader` to divide a page into
 * subsections. Renders a title, an optional description with an embedded
 * "learn more" link, and a row of action buttons that automatically collapse
 * into a dropdown on mobile.
 *
 * Action buttons come from the yielded `:actions` named block. The yield hash
 * gives you `Primary`, `Default`, `Danger`, and `Wrapped` components which on
 * desktop render as buttons and on mobile render as dropdown list items —
 * consumers don't need to branch on viewport.
 *
 * @example
 * <DPageSubheader
 *   @titleLabel={{i18n "admin.badges.title"}}
 *   @descriptionLabel={{i18n "admin.badges.description"}}
 *   @learnMoreUrl="https://meta.discourse.org/t/96331"
 * >
 *   <:actions as |actions|>
 *     <actions.Primary @route="adminBadges.show" @routeModels="new" @label="admin.badges.new" />
 *   </:actions>
 * </DPageSubheader>
 */

/**
 * @typedef DPageSubheaderActions
 * @property {typeof PrimaryButton} Primary Renders as a primary action button on desktop and as a default dropdown list item on mobile.
 * @property {typeof DefaultButton} Default Renders as a default action button on desktop and as a default dropdown list item on mobile.
 * @property {typeof DangerButton} Danger Renders as a danger-styled action button on desktop and as a danger dropdown list item on mobile.
 * @property {typeof WrappedButton} Wrapped Renders arbitrary inline content as an action slot on desktop and as a wrapped dropdown list item on mobile.
 */

/**
 * @typedef DPageSubheaderSignature
 *
 * @property {object} Args
 *
 * @property {string} [Args.titleLabel] Translated text for the section title. Pass through `i18n()` at the call-site.
 * @property {string} [Args.titleUrl] Optional URL to wrap the title in an `<a>`. Use for sections whose name is itself a navigable destination.
 * @property {string} [Args.descriptionLabel] Translated description rendered below the title. The string is passed through `trustHTML`, so it may include markup — make sure the source is already-safe HTML (typically an `i18n()` call).
 * @property {string} [Args.learnMoreUrl] URL appended after `@descriptionLabel` as a "Learn more…" link. Requires `@descriptionLabel` to be visible.
 *
 * @property {HTMLDivElement} Element
 *
 * @property {object} Blocks
 * @property {[DPageSubheaderActions]} Blocks.actions Yields a hash of action-button components. The component types adapt to viewport: buttons on desktop, dropdown list items on mobile.
 */

/** @extends {Component<DPageSubheaderSignature>} */
export default class DPageSubheader extends Component {
  @service site;

  <template>
    {{! @glint-nocheck: DMenu's curried trigger and the dynamic action-component hash surface unknown-element complaints }}
    <div class="d-page-subheader">
      <div class="d-page-subheader__title-row">
        {{#if @titleLabel}}
          <h2 class="d-page-subheader__title">
            {{#if @titleUrl}}
              <a href={{@titleUrl}} class="d-page-subheader__title-link">
                {{@titleLabel}}
              </a>
            {{else}}
              {{@titleLabel}}
            {{/if}}
          </h2>
        {{/if}}
        {{#if (has-block "actions")}}
          <div class="d-page-subheader__actions">
            {{#if this.site.mobileView}}
              <DMenu
                @identifier="d-page-subheader-mobile-actions"
                @title={{i18n "more_options"}}
                @icon="ellipsis-vertical"
                class="btn-small btn-default"
              >
                <:content>
                  <DDropdownMenu class="d-page-subheader__mobile-actions">
                    {{yield
                      (hash
                        Primary=DefaultActionListItem
                        Default=DefaultActionListItem
                        Danger=DangerActionListItem
                        Wrapped=WrappedActionListItem
                      )
                      to="actions"
                    }}
                  </DDropdownMenu>
                </:content>
              </DMenu>
            {{else}}
              {{yield
                (hash
                  Primary=PrimaryButton
                  Default=DefaultButton
                  Danger=DangerButton
                  Wrapped=WrappedButton
                )
                to="actions"
              }}
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if @descriptionLabel}}
        <p class="d-page-subheader__description">
          {{trustHTML @descriptionLabel}}
          {{#if @learnMoreUrl}}
            <span class="d-page-subheader__learn-more">
              {{trustHTML
                (i18n "learn_more_with_link" url=@learnMoreUrl)
              }}</span>
          {{/if}}
        </p>
      {{/if}}
    </div>
  </template>
}
