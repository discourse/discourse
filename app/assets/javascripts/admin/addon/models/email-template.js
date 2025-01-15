import { getProperties } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class EmailTemplate extends RestModel {
  revert() {
    return ajax(`/admin/email/templates/${this.id}`, {
      type: "DELETE",
    }).then((result) =>
      getProperties(result.email_template, "subject", "body", "can_revert")
    );
  }
}
