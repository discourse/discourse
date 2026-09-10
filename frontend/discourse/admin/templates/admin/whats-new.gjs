import DashboardNewFeatures from "discourse/admin/components/dashboard-new-features";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.whats_new.header_description"}}
    @hideTabs={{true}}
    @learnMoreUrl="https://releases.discourse.org/"
    @titleLabel={{i18n "admin.config.whats_new.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.whats_new.title"}}
        @path="/admin/whats-new"
      />
    </:breadcrumbs>
    <:actions as |actions|>
      <actions.Primary
        @action={{@controller.checkForUpdates}}
        @label="admin.new_features.check_for_updates"
      />
    </:actions>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <div class="admin-config-area">
      <DashboardNewFeatures
        @onCheckForFeatures={{@controller.bindCheckFeatures}}
        @scrollTo={{@controller.scrollTo}}
      />
    </div>
  </div>
</template>
