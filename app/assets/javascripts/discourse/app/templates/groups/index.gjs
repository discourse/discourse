import RouteTemplate from "ember-route-template";
import GroupList from "discourse/components/group-list";
import PluginOutlet from "discourse/components/plugin-outlet";

export default RouteTemplate(
  <template>
    <GroupList @controller={{@controller}} />

    <PluginOutlet
      @name="after-groups-index-container"
      @connectorTagName="div"
    />
  </template>
);
