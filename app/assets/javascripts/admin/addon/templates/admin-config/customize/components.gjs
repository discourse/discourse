import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import Components from "admin/components/admin-config-areas/components";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/config/customize/components"
      @label={{i18n
        "admin.config_areas.themes_and_components.components.title"
      }}
    />

    <Components />
  </template>
);
