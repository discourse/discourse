import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="alert alert-info about-customize-colors">{{i18n
        "admin.customize.colors.about"
      }}</div>
  </template>
);
