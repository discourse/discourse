import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-user_fields admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.config.user_fields.title"}}
        @descriptionLabel={{i18n "admin.config.user_fields.header_description"}}
        @hideTabs={{true}}
        @learnMoreUrl="https://meta.discourse.org/t/creating-and-configuring-custom-user-fields/113192"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/config/user-fields"
            @label={{i18n "admin.config.user_fields.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            @route="adminUserFields.new"
            @label="admin.user_fields.add"
          />
        </:actions>
      </DPageHeader>

      <div class="admin-config-page__main-area">
        <div class="user-fields">
          {{outlet}}
        </div>
      </div>
    </div>
  </template>
);
