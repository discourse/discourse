import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  saving: false,

  actions: {
    massAward() {
      const file = document.querySelector("#massAwardCSVUpload").files[0];

      const options = {
        type: "POST",
        processData: false,
        contentType: false,
        data: new FormData()
      };

      options.data.append("file", file);

      this.set("saving", false);

      ajax(`/admin/badges/award/${this.model.id}`, options)
        .then(() => this.set("saving", false))
        .catch(popupAjaxError);
    }
  }
});
