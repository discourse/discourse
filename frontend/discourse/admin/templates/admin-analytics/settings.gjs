import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.analytics.header_description"}}
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.analytics.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.analytics.title"}}
        @path="/admin/config/analytics-and-seo"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @area="analytics"
      @filter={{@controller.filter}}
      @path="/admin/config/analytics-and-seo"
      @showBreadcrumb={{false}}
    />
  </div>
</template>
