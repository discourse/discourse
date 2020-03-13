import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  saving: false,
  replaceBadgeOwners: false,

  actions: {
    massAward() {
      const file = document.querySelector("#massAwardCSVUpload").files[0];

      if (this.model && file) {
        const options = {
          type: "POST",
          processData: false,
          contentType: false,
          data: new FormData()
        };

        options.data.append("file", file);
        options.data.append("replace_badge_owners", this.replaceBadgeOwners);

        this.set("saving", true);

        ajax(`/admin/badges/award/${this.model.id}`, options)
          .then(() => {
            bootbox.alert(I18n.t("admin.badges.mass_award.success"));
          })
          .catch(popupAjaxError)
          .finally(() => this.set("saving", false));
      } else {
        bootbox.alert(I18n.t("admin.badges.mass_award.aborted"));
      }
    }
  }
});
