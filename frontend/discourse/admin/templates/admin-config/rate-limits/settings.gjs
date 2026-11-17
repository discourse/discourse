import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.rate_limits.header_description"}}
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.rate_limits.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.rate_limits.title"}}
        @path="/admin/config/rate-limits"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @categories="rate_limits"
      @filter={{@controller.filter}}
      @path="/admin/config/rate-limits"
      @showBreadcrumb={{false}}
    />
  </div>
</template>
