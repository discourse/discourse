import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class DeleteThemesConfirmComponent extends Component {
  @action
  delete() {
    ajax(`/admin/themes/bulk_destroy.json`, {
      type: "DELETE",
      data: {
        theme_ids: this.args.model.selectedThemesOrComponents.map(
          (item) => item.id
        ),
      },
    })
      .then(() => {
        this.args.model.refreshAfterDelete();
        this.args.closeModal();
      })
      .catch(popupAjaxError);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "admin.customize.bulk_delete"}}
    >
      <:body>
        {{i18n (concat "admin.customize.bulk_" @model.type "_delete_confirm")}}
        <ul>
          {{#each @model.selectedThemesOrComponents as |theme|}}
            <li>{{theme.name}}</li>
          {{/each}}
        </ul>

      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.delete}}
          @label="yes_value"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
