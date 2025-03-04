import RouteTemplate from 'ember-route-template'
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
export default RouteTemplate(<template><form class="groups-form form-vertical">
  <GroupsFormInteractionFields @model={{@controller.model}} />
  <GroupManageSaveButton @model={{@controller.model}} />
</form></template>)