import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.analytics.title"}}
    @descriptionLabel={{i18n "admin.config.analytics.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/analytics-and-seo"
        @label={{i18n "admin.config.analytics.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @showBreadcrumb={{false}}
      @area="analytics"
      @path="/admin/config/analytics-and-seo"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </div>
</template>
