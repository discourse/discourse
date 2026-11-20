import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.api_keys.header_description"}}
    @hideTabs={{@controller.hideTabs}}
    @titleLabel={{i18n "admin.config.api_keys.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.api_keys.title"}}
        @path="/admin/api/keys"
      />
    </:breadcrumbs>
    <:actions as |actions|>
      <actions.Primary @label="admin.api_keys.add" @route="adminApiKeys.new" />
    </:actions>
    <:tabs>
      <DNavItem
        class="admin-api-keys-tabs__settings"
        @label="settings"
        @route="adminApiKeys.settings"
      />
      <DNavItem
        class="admin-api-keys-tabs__index"
        @label="admin.config.api_keys.title"
        @route="adminApiKeys.index"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <PluginOutlet @name="admin-api-keys">
      {{outlet}}
    </PluginOutlet>
  </div>
</template>
