import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import InvitePanel from "discourse/components/invite-panel";
<template><DModal @title={{iN @model.title}} @closeModal={{@closeModal}} @bodyClass="invite modal-panel" class="add-pm-participants">
  <:body>
    <InvitePanel @inviteModel={{@model.inviteModel}} @closeModal={{@closeModal}} />
  </:body>
</DModal></template>