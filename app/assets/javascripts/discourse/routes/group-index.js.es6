import DiscourseRoute from "discourse/routes/discourse";
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
    this.controllerFor("group").set("showing", "members");

    controller.setProperties({
      model,
      filterInput: this._params.filter
    });

    controller.findMembers(true);
  },

  actions: {
    showAddMembersModal() {
      showModal("group-add-members", { model: this.modelFor("group") });
    },

    showBulkAddModal() {
      showModal("group-bulk-add", { model: this.modelFor("group") });
    },

    didTransition() {
      this.controllerFor("group-index").set("filterInput", this._params.filter);
      return true;
    }
  }
});
