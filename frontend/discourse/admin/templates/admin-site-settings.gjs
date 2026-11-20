import AdminSiteSettingsCategoryNav from "discourse/admin/components/admin-site-settings-category-nav";
import AdminSiteSettingsChangesBanner from "discourse/admin/components/admin-site-settings-changes-banner";
import AdminSiteSettingsFilterControls from "discourse/admin/components/admin-site-settings-filter-controls";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n "admin.config.site_settings.header_description"}}
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.site_settings.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
      <DBreadcrumbsItem
        @label={{i18n "admin.config.site_settings.title"}}
        @path="/admin/site_settings"
      />
    </:breadcrumbs>
  </DPageHeader>

  <AdminSiteSettingsFilterControls
    @initialFilter={{@controller.filter}}
    @onChangeFilter={{@controller.filterChanged}}
    @onToggleMenu={{@controller.toggleMenu}}
    @showMenu={{true}}
  />

  <div class="admin-nav admin-site-settings-category-nav pull-left">
    <AdminSiteSettingsCategoryNav
      @categories={{@controller.visibleSiteSettings}}
      @filtersApplied={{@controller.filtersApplied}}
    />
  </div>

  <div class="admin-detail pull-left">
    {{outlet}}
  </div>

  <div class="clearfix"></div>

  <AdminSiteSettingsChangesBanner />
</template>
