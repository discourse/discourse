import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(<template>
  <DPageHeader
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.trust_levels.title"}}
    @descriptionLabel={{i18n "admin.config.trust_levels.header_description"}}
    @learnMoreUrl="https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/"
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/trust-levels"
        @label={{i18n "admin.config.trust_levels.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @showBreadcrumb={{false}}
      @area="trust_levels"
      @path="/admin/config/trust-levels"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </div>
</template>);
