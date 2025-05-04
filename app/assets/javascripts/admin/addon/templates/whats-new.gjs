import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import DashboardNewFeatures from "admin/components/dashboard-new-features";

export default RouteTemplate(
  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.whats_new.title"}}
      @descriptionLabel={{i18n "admin.config.whats_new.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/tags/c/announcements/67/release-notes"
      @hideTabs={{true}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/whats-new"
          @label={{i18n "admin.config.whats_new.title"}}
        />
      </:breadcrumbs>
      <:actions as |actions|>
        <actions.Primary
          @label="admin.new_features.check_for_updates"
          @action={{@controller.checkForUpdates}}
        />
      </:actions>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <div class="admin-config-area">
        <DashboardNewFeatures
          @onCheckForFeatures={{@controller.bindCheckFeatures}}
        />
      </div>
    </div>
  </template>
);
