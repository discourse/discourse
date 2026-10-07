import GroupList from "discourse/components/group-list";
import PluginOutlet from "discourse/components/plugin-outlet";

export default <template>
  <GroupList
    @filter={{@controller.filter}}
    @groups={{@model.groups}}
    @onFilterChanged={{@controller.onFilterChanged}}
    @onTypeChanged={{@controller.onTypeChanged}}
    @type={{@controller.type}}
  />

  <PluginOutlet @connectorTagName="div" @name="after-groups-index-container" />
</template>
