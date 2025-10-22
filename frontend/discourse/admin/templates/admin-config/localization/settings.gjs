import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.localization.title"}}
      @descriptionLabel={{i18n "admin.config.localization.header_description"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/localization"
          @label={{i18n "admin.config.localization.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      <AdminAreaSettings
        @showBreadcrumb={{false}}
        @area="localization"
        @path="/admin/config/localization"
        @filter={{@controller.filter}}
        @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      />
    </div>
  </template>
);
