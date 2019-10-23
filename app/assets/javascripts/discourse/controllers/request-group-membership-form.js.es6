import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  reason: Ember.computed.alias("model.membership_request_template"),

  @computed("model.name")
  title(groupName) {
    return I18n.t("groups.membership_request.title", { group_name: groupName });
  },

  @computed("loading", "reason")
  disableSubmit(loading, reason) {
    return loading || Ember.isEmpty(reason);
  },

  actions: {
    requestMember() {
      if (this.currentUser) {
        this.set("loading", true);

        this.model
          .requestMembership(this.reason)
          .then(result => {
            DiscourseURL.routeTo(result.relative_url);
          })
          .catch(popupAjaxError)
          .finally(() => {
            this.set("loading", false);
          });
      } else {
        this._showLoginModal();
      }
    }
  }
});
