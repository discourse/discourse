import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/ui-kit/d-page-action-button";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

export default class DPageSubheader extends Component {
  @service site;

  /**
   * The element the title renders as. A subheader nested under another heading
   * needs to continue that heading structure rather than restart it at `h2`.
   *
   * @returns {object} A component wrapping the heading tag.
   */
  get titleTag() {
    const level = this.args.titleHeadingLevel ?? 2;

    assert(
      `DPageSubheader @titleHeadingLevel must be 1-6, got ${level}`,
      Number.isInteger(level) && level >= 1 && level <= 6
    );

    return dElement(`h${level}`);
  }

  <template>
    <div class="d-page-subheader">
      <div class="d-page-subheader__title-row">
        {{#if @titleLabel}}
          <this.titleTag class="d-page-subheader__title">
            {{#if @titleUrl}}
              <a class="d-page-subheader__title-link" href={{@titleUrl}}>
                {{@titleLabel}}
              </a>
            {{else}}
              {{@titleLabel}}
            {{/if}}
          </this.titleTag>
        {{/if}}
        {{#if (has-block "actions")}}
          <div class="d-page-subheader__actions">
            {{#if this.site.mobileView}}
              <DMenu
                class="btn-small btn-default"
                @icon="ellipsis-vertical"
                @identifier="d-page-subheader-mobile-actions"
                @title={{i18n "more_options"}}
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
