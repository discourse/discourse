import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.trust_levels.header_description"}}
    @hideTabs={{true}}
    @learnMoreUrl="https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/"
    @titleLabel={{i18n "admin.config.trust_levels.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.trust_levels.title"}}
        @path="/admin/config/trust-levels"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @area="trust_levels"
      @filter={{@controller.filter}}
      @path="/admin/config/trust-levels"
      @showBreadcrumb={{false}}
    />
  </div>
</template>
