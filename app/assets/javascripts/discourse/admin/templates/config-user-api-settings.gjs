import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.user_api.title"}}
      @descriptionLabel={{i18n "admin.config.user_api.header_description"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/user-api"
          @label={{i18n "admin.config.user_api.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      <AdminAreaSettings
        @showBreadcrumb={{false}}
        @categories="user_api"
        @path="/admin/config/user-api"
        @filter={{@controller.filter}}
        @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      />
    </div>
  </template>
);
