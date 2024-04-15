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
