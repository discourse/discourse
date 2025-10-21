import { getProperties } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class SiteText extends RestModel {
  revert(locale) {
    return ajax(`/admin/customize/site_texts/${this.id}?locale=${locale}`, {
      type: "DELETE",
    }).then((result) => getProperties(result.site_text, "value", "can_revert"));
  }

  dismissOutdated(locale) {
    return ajax(
      `/admin/customize/site_texts/${this.id}/dismiss_outdated?locale=${locale}`,
      {
        type: "PUT",
      }
    );
  }
}
