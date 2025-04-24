import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";
import ThemeSiteSettings from "admin/components/theme-site-settings";

export default RouteTemplate(
  <template>
    <DPageHeader
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.theme_site_settings.title"}}
      @descriptionLabel={{i18n
        "admin.config.theme_site_settings.header_description"
      }}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/theme-site-settings"
          @label={{i18n "admin.config.theme_site_settings.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      <ThemeSiteSettings />
    </div>
  </template>
);
