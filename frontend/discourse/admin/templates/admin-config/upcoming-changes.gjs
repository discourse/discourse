import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminConfigAreasUpcomingChanges from "admin/components/admin-config-areas/upcoming-changes";

export default <template>
  <DPageHeader
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.upcoming_changes.title"}}
    @descriptionLabel={{i18n
      "admin.config.upcoming_changes.header_description"
    }}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/upcoming-changes"
        @label={{i18n "admin.config.upcoming_changes.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminConfigAreasUpcomingChanges @upcomingChanges={{@controller.model}} />
  </div>
</template>
