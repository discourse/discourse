import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @descriptionLabel={{i18n
      "admin.config.themes_and_components.header_description"
    }}
    @learnMoreUrl="https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966"
    @titleLabel={{i18n "admin.config.themes_and_components.title"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
    </:breadcrumbs>

    <:tabs>
      <DNavItem
        @label="admin.config.themes.title"
        @route="adminConfig.customize.themes"
      />
      <DNavItem
        @label="admin.config.components.title"
        @route="adminConfig.customize.components"
      />
      <DNavItem
        @label="admin.config.theme_site_settings.title"
        @route="adminConfig.customize.themeSiteSettings"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <PluginOutlet @name="admin-config-customize">
      {{outlet}}
    </PluginOutlet>
  </div>
</template>
