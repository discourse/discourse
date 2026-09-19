import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.groups.header_description"}}
    @hideTabs={{@controller.hideTabs}}
    @titleLabel={{i18n "admin.config.groups.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.groups.title"}}
        @path="/admin/groups"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        class="admin-groups-tabs__settings"
        @label="settings"
        @route="adminGroups.settings"
      />
      <DNavItem
        class="admin-groups-tabs__index"
        @label="admin.config.groups.title"
        @route="adminGroups.index"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
