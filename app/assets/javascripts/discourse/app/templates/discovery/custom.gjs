import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <PluginOutlet @name="custom-homepage">
      {{#if @controller.currentUser.admin}}
        <p class="alert alert-info">
          {{i18n "custom_homepage.admin_message"}}
        </p>
      {{/if}}
    </PluginOutlet>
  </template>
);
