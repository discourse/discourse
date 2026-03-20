import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
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
      <actions.Primary @route="adminApiKeys.new" @label="admin.api_keys.add" />
    </:actions>
    <:tabs>
      <DNavItem
        @route="adminApiKeys.settings"
        @label="settings"
        class="admin-api-keys-tabs__settings"
      />
      <DNavItem
        @route="adminApiKeys.index"
        @label="admin.config.api_keys.title"
        class="admin-api-keys-tabs__index"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <PluginOutlet @name="admin-api-keys">
      {{outlet}}
    </PluginOutlet>
  </div>
</template>
