import RouteTemplate from "ember-route-template";
import GroupManageEmailSettings from "discourse/components/group-manage-email-settings";

export default RouteTemplate(
  <template><GroupManageEmailSettings @group={{@controller.model}} /></template>
);
