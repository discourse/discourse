import { concat } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.siteSettings.use_overhauled_theme_color_palette}}
      {{#unless @controller.model.component}}
        <DPageHeader>
          <:breadcrumbs>
            <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
            <DBreadcrumbsItem
              @path="/admin/config/customize/themes"
              @label={{i18n
                "admin.config_areas.themes_and_components.themes.title"
              }}
            />
            <DBreadcrumbsItem
              @path={{concat "/admin/customize/themes/" @controller.model.id}}
              @label={{@controller.model.name}}
            />
          </:breadcrumbs>

          <:tabs>
            <NavItem
              class="admin-customize-theme-tabs__settings"
              @route="adminCustomizeThemes.show.index"
              @routeParam={{@controller.model.id}}
              @label="admin.customize.theme.settings"
            />
            <NavItem
              class="admin-customize-theme-tabs__colors"
              @route="adminCustomizeThemes.show.colors"
              @routeParam={{@controller.model.id}}
              @label="admin.customize.theme.colors"
            />
          </:tabs>
        </DPageHeader>
      {{/unless}}
    {{/if}}

    {{outlet}}
  </template>
);
