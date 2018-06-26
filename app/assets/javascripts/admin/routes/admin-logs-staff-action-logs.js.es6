import showModal from "discourse/lib/show-modal";

export default Discourse.Route.extend({
  // TODO: make this automatic using an `{{outlet}}`
  renderTemplate: function() {
    this.render("admin/templates/logs/staff-action-logs", {
      into: "adminLogs"
    });
  },

  actions: {
    showDetailsModal(model) {
      showModal("admin-staff-action-log-details", { model, admin: true });
      this.controllerFor("modal").set("modalClass", "log-details-modal");
    },

    showCustomDetailsModal(model) {
      let modal = showModal("admin-theme-change", { model, admin: true });
      this.controllerFor("modal").set("modalClass", "history-modal");
      modal.loadDiff();
    }
  }
});
