import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupsFormMembershipFields from "discourse/components/groups-form-membership-fields";

<template>
  <form class="groups-form form-vertical">
    <GroupsFormMembershipFields @model={{@controller.model}} />
    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
