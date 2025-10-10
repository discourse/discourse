import RouteTemplate from "ember-route-template";
import GroupList from "discourse/components/group-list";

export default RouteTemplate(
  <template>
    <GroupList
      @groups={{@model.groups}}
      @type={{@controller.type}}
      @filter={{@controller.filter}}
      @onTypeChanged={{@controller.onTypeChanged}}
      @onFilterChanged={{@controller.onFilterChanged}}
    />
  </template>
);
