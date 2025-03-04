import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import { concat } from "@ember/helper";
import DButton from "discourse/components/d-button";

export default class AssociateAccountConfirm extends Component {<template><DModal @title={{iN "user.associated_accounts.confirm_modal_title" provider=(iN (concat "login." @model.provider_name ".name"))}} @closeModal={{@closeModal}} @flash={{this.flash}} @flashType="error">
  <:body>
    {{#if @model.existing_account_description}}
      <p>
        {{iN "user.associated_accounts.confirm_description.disconnect" provider=(iN (concat "login." @model.provider_name ".name")) account_description=@model.existing_account_description}}
      </p>
    {{/if}}

    <p>
      {{#if @model.account_description}}
        {{iN "user.associated_accounts.confirm_description.account_specific" provider=(iN (concat "login." @model.provider_name ".name")) account_description=@model.account_description}}
      {{else}}
        {{iN "user.associated_accounts.confirm_description.generic" provider=(iN (concat "login." @model.provider_name ".name"))}}
      {{/if}}
    </p>
  </:body>

  <:footer>
    <DButton @label="user.associated_accounts.connect" @action={{this.finishConnect}} @icon="plug" class="btn-primary" />
    <DButton @label="user.associated_accounts.cancel" @action={{@closeModal}} />
  </:footer>
</DModal></template>
  @service router;
  @service currentUser;

  @tracked flash;

  @action
  async finishConnect() {
    try {
      const result = await ajax({
        url: `/associate/${encodeURIComponent(this.args.model.token)}`,
        type: "POST",
      });

      if (result.success) {
        this.router.transitionTo(
          "preferences.account",
          this.currentUser.findDetails()
        );
        this.args.closeModal();
      } else {
        this.flash = result.error;
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
