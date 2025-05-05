import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import AdminSiteSettingsChangesBanner from "admin/components/admin-site-settings-changes-banner";
import AdminSiteSettingsFilterControls from "admin/components/admin-site-settings-filter-controls";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
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
      @controller={{@controller}}
    />

    <div class="admin-detail pull-left mobile-closed">
      {{outlet}}
    </div>

    <div class="clearfix"></div>

    <AdminSiteSettingsChangesBanner />
  </template>
);
