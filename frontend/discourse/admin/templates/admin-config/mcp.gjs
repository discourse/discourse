import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.mcp.title"}}
    @descriptionLabel={{i18n "admin.config.mcp.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/mcp"
        @label={{i18n "admin.config.mcp.title"}}
      />
    </:breadcrumbs>
    <:tabs>
      <DNavItem
        @route="adminConfig.mcp.index"
        @label="admin.config.mcp.tabs.overview"
        class="admin-mcp-tabs__overview"
      />
      <DNavItem
        @route="adminConfig.mcp.capabilities"
        @label="admin.config.mcp.tabs.capabilities"
        class="admin-mcp-tabs__capabilities"
      />
      <DNavItem
        @route="adminConfig.mcp.clients"
        @label="admin.config.mcp.tabs.clients"
        class="admin-mcp-tabs__clients"
      />
      <DNavItem
        @route="adminConfig.mcp.authorizations"
        @label="admin.config.mcp.tabs.authorizations"
        class="admin-mcp-tabs__authorizations"
      />
      <DNavItem
        @route="adminConfig.mcp.activity"
        @label="admin.config.mcp.tabs.activity"
        class="admin-mcp-tabs__activity"
      />
      <DNavItem
        @route="adminConfig.mcp.settings"
        @label="settings"
        class="admin-mcp-tabs__settings"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area admin-mcp">
    {{outlet}}
  </div>
</template>
