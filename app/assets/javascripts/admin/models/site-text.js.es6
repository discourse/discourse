import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
const { getProperties } = Ember;

export default RestModel.extend({
  revert() {
    return ajax(`/admin/customize/site_texts/${this.id}`, {
      type: "DELETE"
    }).then(result => getProperties(result.site_text, "value", "can_revert"));
  }
});
