import RouteTemplate from 'ember-route-template'
import GroupsFormProfileFields from "discourse/components/groups-form-profile-fields";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
export default RouteTemplate(<template><form class="groups-form form-vertical">
  <GroupsFormProfileFields @model={{@controller.model}} @disableSave={{@controller.saving}} />
  <GroupManageSaveButton @model={{@controller.model}} @saving={{@controller.saving}} />
</form></template>)