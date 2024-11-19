import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DropdownMenu from "discourse/components/dropdown-menu";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import { i18n } from "discourse-i18n";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryActionListItem,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "admin/components/admin-page-action-button";
import DMenu from "float-kit/components/d-menu";

export default class AdminPageHeader extends Component {
  @service site;

  get title() {
    if (this.args.titleLabelTranslated) {
      return this.args.titleLabelTranslated;
    } else if (this.args.titleLabel) {
      return i18n(this.args.titleLabel);
    }
  }

  get description() {
    if (this.args.descriptionLabelTranslated) {
      return this.args.descriptionLabelTranslated;
    } else if (this.args.descriptionLabel) {
      return i18n(this.args.descriptionLabel);
    }
  }

  <template>
    <div class="admin-page-header">
      <div class="admin-page-header__breadcrumbs">
        <DBreadcrumbsContainer />
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        {{yield to="breadcrumbs"}}
      </div>

      <div class="admin-page-header__title-row">
        {{#if this.title}}
          <h1 class="admin-page-header__title">{{this.title}}</h1>
        {{/if}}

        {{#if (or (has-block "actions") @headerActionComponent)}}
          <div class="admin-page-header__actions">
            {{#if this.site.mobileView}}
              <DMenu
                @identifier="admin-page-header-mobile-actions"
                @title={{i18n "more_options"}}
                @icon="ellipsis-vertical"
                class="btn-small"
              >
                <:content>
                  <DropdownMenu class="admin-page-header__mobile-actions">
                    {{#let
                      (hash
                        Primary=PrimaryActionListItem
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

      {{#if this.description}}
        <p class="admin-page-header__description">
          {{htmlSafe this.description}}
          {{#if @learnMoreUrl}}
            <span class="admin-page-header__learn-more">{{htmlSafe
                (i18n "learn_more_with_link" url=@learnMoreUrl)
              }}</span>
          {{/if}}
        </p>
      {{/if}}

      {{#unless @hideTabs}}
        <div class="admin-nav-submenu">
          <HorizontalOverflowNav class="admin-nav-submenu__tabs">
            {{yield to="tabs"}}
          </HorizontalOverflowNav>
        </div>
      {{/unless}}
    </div>
  </template>
}
