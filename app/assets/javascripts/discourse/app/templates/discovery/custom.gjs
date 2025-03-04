import RouteTemplate from 'ember-route-template'
import PluginOutlet from "discourse/components/plugin-outlet";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><PluginOutlet @name="custom-homepage">
  {{#if @controller.currentUser.admin}}
    <p class="alert alert-info">
      {{iN "custom_homepage.admin_message"}}
    </p>
  {{/if}}
</PluginOutlet></template>)