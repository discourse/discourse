import Component from "@glimmer/component";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import DButton from "discourse/components/d-button";

export default class GroupDefaultNotifications extends Component {<template><DModal @title={{iN "groups.default_notifications.modal_title"}} @closeModal={{@closeModal}}>
  <:body>
    {{iN "groups.default_notifications.modal_description" count=@model.count}}
  </:body>
  <:footer>
    <DButton @action={{this.updateExistingUsers}} @label="groups.default_notifications.modal_yes" class="btn-primary" />
    <DButton @action={{this.cancel}} @label="groups.default_notifications.modal_no" />
  </:footer>
</DModal></template>
  @action
  updateExistingUsers() {
    this.args.model.setUpdateExistingUsers(true);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.setUpdateExistingUsers(false);
    this.args.closeModal();
  }
}
