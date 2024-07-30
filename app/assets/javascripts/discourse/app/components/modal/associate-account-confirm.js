import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AssociateAccountConfirm extends Component {
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
