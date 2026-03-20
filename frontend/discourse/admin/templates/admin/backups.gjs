import AdminBackupsActions from "discourse/admin/components/admin-backups-actions";
import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-backups admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.config.backups.title"}}
      @descriptionLabel={{i18n "admin.config.backups.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/create-download-and-restore-a-backup-of-your-discourse-database/122710"
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/backups"
          @label={{i18n "admin.config.backups.title"}}
        />
      </:breadcrumbs>
      <:actions as |actions|>
        {{#if @controller.siteSettings.enable_backups}}
          <AdminBackupsActions @actions={{actions}} @backups={{@model}} />
        {{/if}}
      </:actions>
      <:tabs>
        <DNavItem
          @route="admin.backups.settings"
          @label="settings"
          class="admin-backups-tabs__settings"
        />
        <DNavItem
          @route="admin.backups.index"
          @label="admin.backups.menu.backup_files"
          class="admin-backups-tabs__files"
        />
        <DNavItem
          @route="admin.backups.logs"
          @label="admin.backups.menu.logs"
          class="admin-backups-tabs__logs"
        />
        <PluginOutlet @name="downloader" @connectorTagName="div" />
      </:tabs>
    </DPageHeader>

    <PluginOutlet @name="before-backup-list" @connectorTagName="div" />

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
