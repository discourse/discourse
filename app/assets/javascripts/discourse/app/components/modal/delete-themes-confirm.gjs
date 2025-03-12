import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class DeleteThemesConfirmComponent extends Component {
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
    <DButton class="btn-primary" @action={{this.delete}} @label="yes_value" />
    <DModalCancel @close={{@closeModal}} />
  </:footer>
</DModal>