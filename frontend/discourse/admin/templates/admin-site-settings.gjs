import AdminSiteSettingsCategoryNav from "discourse/admin/components/admin-site-settings-category-nav";
import AdminSiteSettingsChangesBanner from "discourse/admin/components/admin-site-settings-changes-banner";
import AdminSiteSettingsFilterControls from "discourse/admin/components/admin-site-settings-filter-controls";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.site_settings.title"}}
    @descriptionLabel={{i18n "admin.config.site_settings.header_description"}}
    @hideTabs={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/site_settings"
        @label={{i18n "admin.config.site_settings.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <AdminSiteSettingsFilterControls
    @initialFilter={{@controller.filter}}
    @onChangeFilter={{@controller.filterChanged}}
    @showMenu={{true}}
    @onToggleMenu={{@controller.toggleMenu}}
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
