import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/components/d-modal";
import iN from "discourse/helpers/i18n";
import { concat } from "@ember/helper";
import DButton from "discourse/components/d-button";
import DModalCancel from "discourse/components/d-modal-cancel";

export default class DeleteThemesConfirmComponent extends Component {<template><DModal @closeModal={{@closeModal}} @title={{iN "admin.customize.bulk_delete"}}>
  <:body>
    {{iN (concat "admin.customize.bulk_" @model.type "_delete_confirm")}}
    <ul>
      {{#each @model.selectedThemesOrComponents as |theme|}}
        <li>{{theme.name}}</li>
      {{/each}}
    </ul>

  </:body>
  <:footer>
    <DButton class="btn-primary" @action={{this.delete}} @label="yes_value" />
    <DModalCancel @close={{@closeModal}} />
  </:footer>
</DModal></template>
  @action
  delete() {
    ajax(`/admin/themes/bulk_destroy.json`, {
      type: "DELETE",
      data: {
        theme_ids: this.args.model.selectedThemesOrComponents.mapBy("id"),
      },
    })
      .then(() => {
        this.args.model.refreshAfterDelete();
        this.args.closeModal();
      })
      .catch(popupAjaxError);
  }
}
