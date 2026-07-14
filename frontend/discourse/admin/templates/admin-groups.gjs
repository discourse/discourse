import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.groups.title"}}
    @descriptionLabel={{i18n "admin.config.groups.header_description"}}
    @hideTabs={{@controller.hideTabs}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/groups"
        @label={{i18n "admin.config.groups.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminGroups.settings"
        @label="settings"
        class="admin-groups-tabs__settings"
      />
      <DNavItem
        @route="adminGroups.index"
        @label="admin.config.groups.title"
        class="admin-groups-tabs__index"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    {{outlet}}
  </div>
</template>
