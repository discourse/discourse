import AdminConfigAreasUpcomingChanges from "discourse/admin/components/admin-config-areas/upcoming-changes";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n
      "admin.config.upcoming_changes.header_description"
    }}
    @hideTabs={{true}}
    @learnMoreUrl="https://meta.discourse.org/t/-/392894"
    @titleLabel={{i18n "admin.config.upcoming_changes.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.upcoming_changes.title"}}
        @path="/admin/config/upcoming-changes"
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminConfigAreasUpcomingChanges
      @changeNamesFilter={{@controller.changeNamesFilter}}
      @onClearChangeNamesFilter={{@controller.clearChangeNamesFilter}}
      @upcomingChanges={{@controller.model}}
    />
  </div>
</template>
