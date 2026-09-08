import ThemeSiteSettings from "discourse/admin/components/theme-site-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n
      "admin.config_areas.themes_and_components.theme_site_settings.title"
    }}
    @path="/admin/config/customize/theme-site-settings"
  />

  <DPageSubheader
    @descriptionLabel={{i18n
      "admin.config_areas.themes_and_components.theme_site_settings.description"
    }}
    @titleLabel={{i18n
      "admin.config_areas.themes_and_components.theme_site_settings.title"
    }}
  />

  <ThemeSiteSettings />
</template>
