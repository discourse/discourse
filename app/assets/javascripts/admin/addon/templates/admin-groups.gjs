import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminGroups.settings"
          @label="settings"
          class="admin-groups-tabs__settings"
        />
        <NavItem
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
);
