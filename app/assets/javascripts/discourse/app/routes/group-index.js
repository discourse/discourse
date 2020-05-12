import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("groups.members.title");
  },

  model(params) {
    this._params = params;
    return this.modelFor("group");
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
      filterInput: this._params.filter,
      showing: "members"
    });

    controller.findMembers(true);
  },

  @action
  showAddMembersModal() {
    showModal("group-add-members", { model: this.modelFor("group") });
  },

  @action
  showBulkAddModal() {
    showModal("group-bulk-add", { model: this.modelFor("group") });
  },

  @action
  didTransition() {
    this.controllerFor("group-index").set("filterInput", this._params.filter);
    return true;
  }
});
