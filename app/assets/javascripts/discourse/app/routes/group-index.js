import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

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
      showing: "members",
    });

    controller.findMembers(true);
  },

  @action
  showAddMembersModal() {
    showModal("group-add-members", { model: this.modelFor("group") });
  },

  @action
  didTransition() {
    this.controllerFor("group-index").set("filterInput", this._params.filter);
    return true;
  },
});
