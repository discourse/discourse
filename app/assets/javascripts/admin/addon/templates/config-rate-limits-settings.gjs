import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(<template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.rate_limits.title"}}
    @descriptionLabel={{i18n "admin.config.rate_limits.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/rate-limits"
        @label={{i18n "admin.config.rate_limits.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @categories="rate_limits"
      @path="/admin/config/rate-limits"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </div>
</template>);
