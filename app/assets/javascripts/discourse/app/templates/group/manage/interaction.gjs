import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";

<template>
  <form class="groups-form form-vertical">
    <GroupsFormInteractionFields @model={{@controller.model}} />
    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
