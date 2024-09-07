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

const AdminPageHeader = <template>
  <div class="admin-page-header">
    <div class="admin-page-header__breadcrumbs">
      <DBreadcrumbsContainer />
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      {{yield to="breadcrumbs"}}
    </div>

    <div class="admin-page-header__title-row">
      {{#if @titleLabel}}
        <h1 class="admin-page-header__title">{{i18n @titleLabel}}</h1>
      {{/if}}
      <div class="admin-page-header__actions">
        {{yield
          (hash Primary=PrimaryButton Default=DefaultButton Danger=DangerButton)
          to="actions"
        }}
      </div>
    </div>

    {{#if @descriptionLabel}}
      <p class="admin-page-header__description">
        {{i18n @descriptionLabel}}
        {{#if @learnMoreUrl}}
          {{htmlSafe (i18n "learn_more_with_link" url=@learnMoreUrl)}}
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
</template>;

export default AdminPageHeader;
