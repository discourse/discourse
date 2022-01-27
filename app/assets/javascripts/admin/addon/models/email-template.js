import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";
import { getProperties } from "@ember/object";

export default RestModel.extend({
  revert() {
    return ajax(`/admin/customize/email_templates/${this.id}`, {
      type: "DELETE",
    }).then((result) =>
      getProperties(result.email_template, "subject", "body", "can_revert")
    );
  },
});
