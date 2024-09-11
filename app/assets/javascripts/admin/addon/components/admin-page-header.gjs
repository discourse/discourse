import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import i18n from "discourse-common/helpers/i18n";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "admin/components/admin-page-action-button";

export default class AdminPageHeader extends Component {
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

        <div class="admin-page-header__actions">
          {{yield
            (hash
              Primary=PrimaryButton Default=DefaultButton Danger=DangerButton
            )
            to="actions"
          }}
        </div>
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
