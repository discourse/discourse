import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import ThemeSiteSettings from "admin/components/theme-site-settings";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/config/customize/theme-site-settings"
      @label={{i18n
        "admin.config_areas.themes_and_components.theme_site_settings.title"
      }}
    />

    <DPageSubheader
      @titleLabel={{i18n
        "admin.config_areas.themes_and_components.theme_site_settings.title"
      }}
      @descriptionLabel={{i18n
        "admin.config_areas.themes_and_components.theme_site_settings.description"
      }}
    />

    <ThemeSiteSettings />
  </template>
);
