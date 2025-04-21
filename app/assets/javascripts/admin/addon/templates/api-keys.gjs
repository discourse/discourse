import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <PluginOutlet @name="admin-api-keys">
      <DPageHeader
        @titleLabel={{i18n "admin.config.api_keys.title"}}
        @descriptionLabel={{i18n "admin.config.api_keys.header_description"}}
        @hideTabs={{@controller.hideTabs}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/api/keys"
            @label={{i18n "admin.config.api_keys.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            @route="adminApiKeys.new"
            @label="admin.api_keys.add"
          />
        </:actions>
        <:tabs>
          <NavItem
            @route="adminApiKeys.settings"
            @label="settings"
            class="admin-api-keys-tabs__settings"
          />
          <NavItem
            @route="adminApiKeys.index"
            @label="admin.config.api_keys.title"
            class="admin-api-keys-tabs__index"
          />
        </:tabs>
      </DPageHeader>

      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </PluginOutlet>
  </template>
);
