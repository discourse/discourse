import RouteTemplate from 'ember-route-template'
import UserApiKeys from "discourse/components/user-preferences/user-api-keys";
import PluginOutlet from "discourse/components/plugin-outlet";
import { hash } from "@ember/helper";
export default RouteTemplate(<template><UserApiKeys @model={{@model}} />

<span>
  <PluginOutlet @name="user-preferences-apps" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
</span></template>)