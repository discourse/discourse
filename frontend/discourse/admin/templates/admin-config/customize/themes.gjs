import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import Themes from "admin/components/admin-config-areas/themes";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/config/customize/themes"
      @label={{i18n "admin.config_areas.themes_and_components.themes.title"}}
    />

    <Themes
      @repoUrl={{@controller.model.repoUrl}}
      @repoName={{@controller.model.repoName}}
      @themes={{@controller.model.themes}}
      @clearParams={{this.clearParams}}
    />
  </template>
);
