import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        <NavItem
          @route="adminConfig.customize.themes"
          @label="admin.config.themes.title"
        />
        <NavItem
          @route="adminConfig.customize.components"
          @label="admin.config.components.title"
        />
      </:tabs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <PluginOutlet @name="admin-config-customize">
        {{outlet}}
      </PluginOutlet>
    </div>
  </template>
);
