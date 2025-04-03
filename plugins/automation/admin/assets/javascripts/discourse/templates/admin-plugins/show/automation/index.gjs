import RouteTemplate from "ember-route-template";
import AutomationList from "discourse/plugins/chat/admin/components/automation-list";

export default RouteTemplate(
  <template><AutomationList @model={{@controller.model}} /></template>
);
