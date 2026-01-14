import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupsFormProfileFields from "discourse/components/groups-form-profile-fields";

export default <template>
  <form class="groups-form form-vertical">
    <GroupsFormProfileFields
      @model={{@controller.model}}
      @disableSave={{@controller.saving}}
    />
    <GroupManageSaveButton
      @model={{@controller.model}}
      @saving={{@controller.saving}}
    />
  </form>
</template>
