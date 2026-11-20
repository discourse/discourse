import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.spam.header_description"}}
    @hideTabs={{true}}
    @learnMoreUrl="https://meta.discourse.org/t/tips-for-preventing-spam/264020"
    @titleLabel={{i18n "admin.config.spam.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.spam.title"}}
        @path="/admin/config/spam"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      @categories="spam"
      @filter={{@controller.filter}}
      @path="/admin/config/spam"
      @showBreadcrumb={{false}}
    />
  </div>
</template>
