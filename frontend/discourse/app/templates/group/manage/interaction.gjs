import RouteTemplate from "ember-route-template";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";

export default RouteTemplate(
  <template>
    <form class="groups-form form-vertical">
      <GroupsFormInteractionFields @model={{@controller.model}} />
      <GroupManageSaveButton @model={{@controller.model}} />
    </form>
  </template>
);
