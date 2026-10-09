import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-user_fields admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.user_fields.header_description"}}
      @hideTabs={{true}}
      @learnMoreUrl="https://meta.discourse.org/t/creating-and-configuring-custom-user-fields/113192"
      @titleLabel={{i18n "admin.config.user_fields.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.user_fields.title"}}
          @path="/admin/config/user-fields"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          @label="admin.user_fields.add"
          @route="adminUserFields.new"
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
