import Component from "@glimmer/component";
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
import { i18n } from "discourse-i18n";

const SubheaderActions = <template>
  <div class="d-page-subheader__actions">
    {{#if @mobileView}}
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
      }}
    {{/if}}
  </div>
</template>;

const SubheaderDescription = <template>
  <p class="d-page-subheader__description">
    {{trustHTML @descriptionLabel}}
    {{#if @learnMoreUrl}}
      <span class="d-page-subheader__learn-more">
        {{trustHTML (i18n "learn_more_with_link" url=@learnMoreUrl)}}</span>
    {{/if}}
  </p>
</template>;

export default class DPageSubheader extends Component {
  @service pageHeader;
  @service site;

  get tabActionsElement() {
    if (this.args.actionsPlacement !== "tabs") {
      return null;
    }

    const header = this.pageHeader.current;
    return header?.showsTabs ? header.tabActionsElement : null;
  }

  <template>
    {{#if (and this.tabActionsElement (has-block "actions"))}}
      {{#in-element this.tabActionsElement insertBefore=null}}
        <SubheaderActions @mobileView={{this.site.mobileView}} as |actions|>
          {{yield actions to="actions"}}
        </SubheaderActions>
      {{/in-element}}

      {{#if @descriptionLabel}}
        <div class="d-page-subheader">
          <SubheaderDescription
            @descriptionLabel={{@descriptionLabel}}
            @learnMoreUrl={{@learnMoreUrl}}
          />
        </div>
      {{/if}}
    {{else}}
      <div class="d-page-subheader">
        <div class="d-page-subheader__title-row">
          {{#if @titleLabel}}
            <h2 class="d-page-subheader__title">
              {{#if @titleUrl}}
                <a class="d-page-subheader__title-link" href={{@titleUrl}}>
                  {{@titleLabel}}
                </a>
              {{else}}
                {{@titleLabel}}
              {{/if}}
            </h2>
          {{/if}}
          {{#if (has-block "actions")}}
            <SubheaderActions @mobileView={{this.site.mobileView}} as |actions|>
              {{yield actions to="actions"}}
            </SubheaderActions>
          {{/if}}
        </div>

        {{#if @descriptionLabel}}
          <SubheaderDescription
            @descriptionLabel={{@descriptionLabel}}
            @learnMoreUrl={{@learnMoreUrl}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
