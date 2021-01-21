import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";
import { getProperties } from "@ember/object";

export default RestModel.extend({
  revert(locale) {
    return ajax(`/admin/customize/site_texts/${this.id}?locale=${locale}`, {
      type: "DELETE",
    }).then((result) => getProperties(result.site_text, "value", "can_revert"));
  },
});
