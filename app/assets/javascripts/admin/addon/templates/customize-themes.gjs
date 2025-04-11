import RouteTemplate from "ember-route-template";
import { eq, or } from "truth-helpers";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import PluginOutlet from "discourse/components/plugin-outlet";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import ThemesList from "admin/components/themes-list";

export default RouteTemplate(
  <template>
    {{#unless @controller.fromNewConfigPage}}
      {{#if (eq @controller.currentTab "themes")}}
        <DPageHeader
          @titleLabel={{i18n "admin.config.themes.title"}}
          @descriptionLabel={{i18n "admin.config.themes.header_description"}}
          @learnMoreUrl="https://meta.discourse.org/t/91966"
          @hideTabs={{true}}
        >
          <:breadcrumbs>
            <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
            <DBreadcrumbsItem
              @path="/admin/customize/themes"
              @label={{i18n "admin.config.themes.title"}}
            />
          </:breadcrumbs>
        </DPageHeader>
      {{else}}
        <DPageHeader
          @titleLabel={{i18n "admin.config.components.title"}}
          @descriptionLabel={{i18n
            "admin.config.components.header_description"
          }}
          @hideTabs={{true}}
        >
          <:breadcrumbs>
            <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
            <DBreadcrumbsItem
              @path="/admin/customize/components"
              @label={{i18n "admin.config.components.title"}}
            />
          </:breadcrumbs>
        </DPageHeader>
      {{/if}}
    {{/unless}}

    <PluginOutlet @name="admin-customize-themes">
      {{#unless (or @controller.editingTheme @controller.fromNewConfigPage)}}
        <ThemesList
          @themes={{@controller.fullThemes}}
          @components={{@controller.childThemes}}
          @currentTab={{@controller.currentTab}}
          @installModal={{routeAction "installModal"}}
        />
      {{/unless}}
      {{outlet}}
    </PluginOutlet>
  </template>
);
