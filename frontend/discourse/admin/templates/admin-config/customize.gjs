import PluginOutlet from "discourse/components/plugin-outlet";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.themes_and_components.title"}}
    @descriptionLabel={{i18n
      "admin.config.themes_and_components.header_description"
    }}
    @learnMoreUrl="https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966"
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    </:breadcrumbs>

    <:tabs>
      <DNavItem
        @route="adminConfig.customize.themes"
        @label="admin.config.themes.title"
      />
      <DNavItem
        @route="adminConfig.customize.components"
        @label="admin.config.components.title"
      />
      <DNavItem
        @route="adminConfig.customize.themeSiteSettings"
        @label="admin.config.theme_site_settings.title"
      />
    </:tabs>
  </DPageHeader>

  <div class="admin-container admin-config-page__main-area">
    <PluginOutlet @name="admin-config-customize">
      {{outlet}}
    </PluginOutlet>
  </div>
</template>
