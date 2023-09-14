import Component from "@ember/component";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  loading: false,
  reason: alias("model.group.membership_request_template"),

  @discourseComputed("model.group.name")
  title(groupName) {
    return I18n.t("groups.membership_request.title", { group_name: groupName });
  },

  @discourseComputed("loading", "reason")
  disableSubmit(loading, reason) {
    return loading || isEmpty(reason);
  },

  @action
  requestMember() {
    this.set("loading", true);

    this.model.group
      .requestMembership(this.reason)
      .then((result) => {
        DiscourseURL.routeTo(result.relative_url);
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.set("loading", false);
      });
  },
});
