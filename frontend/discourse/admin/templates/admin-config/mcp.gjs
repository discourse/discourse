import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.mcp.header_description"}}
    @titleLabel={{i18n "admin.config.mcp.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.mcp.title"}}
        @path="/admin/config/mcp"
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        class="admin-mcp-tabs__overview"
        @label="admin.config.mcp.tabs.overview"
        @route="adminConfig.mcp.index"
      />
      <DNavItem
        class="admin-mcp-tabs__capabilities"
        @label="admin.config.mcp.tabs.capabilities"
        @route="adminConfig.mcp.capabilities"
      />
      <DNavItem
        class="admin-mcp-tabs__access"
        @label="admin.config.mcp.tabs.access"
        @route="adminConfig.mcp.access"
      />
      <DNavItem
        class="admin-mcp-tabs__clients"
        @label="admin.config.mcp.tabs.clients"
        @route="adminConfig.mcp.clients"
      />
      <DNavItem
        class="admin-mcp-tabs__authorizations"
        @label="admin.config.mcp.tabs.authorizations"
        @route="adminConfig.mcp.authorizations"
      />
      <DNavItem
        class="admin-mcp-tabs__activity"
        @label="admin.config.mcp.tabs.activity"
        @route="adminConfig.mcp.activity"
      />
      <DNavItem
        class="admin-mcp-tabs__settings"
        @label="settings"
        @route="adminConfig.mcp.settings"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area admin-mcp">
    {{outlet}}
  </div>
</template>
