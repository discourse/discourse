import AdminBackupsActions from "discourse/admin/components/admin-backups-actions";
import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-backups admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.backups.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/create-download-and-restore-a-backup-of-your-discourse-database/122710"
      @titleLabel={{i18n "admin.config.backups.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.backups.title"}}
          @path="/admin/backups"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        {{#if @controller.siteSettings.enable_backups}}
          <AdminBackupsActions @actions={{actions}} @backups={{@model}} />
        {{/if}}
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-backups-tabs__settings"
          @label="settings"
          @route="admin.backups.settings"
        />
        <DNavItem
          class="admin-backups-tabs__files"
          @label="admin.backups.menu.backup_files"
          @route="admin.backups.index"
        />
        <DNavItem
          class="admin-backups-tabs__logs"
          @label="admin.backups.menu.logs"
          @route="admin.backups.logs"
        />
        <PluginOutlet @connectorTagName="div" @name="downloader" />
      </:tabs>
    </DPageHeader>

    <PluginOutlet @connectorTagName="div" @name="before-backup-list" />

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
