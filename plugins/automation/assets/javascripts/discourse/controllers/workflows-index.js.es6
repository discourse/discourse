import showModal from "discourse/lib/show-modal";

export default Ember.Controller.extend({
  actions: {
    setupWorkflow(workflowable) {
      const workflow = this.store.createRecord("workflow");
      const controller = showModal("create-workflow");
      controller.setProperties({
        workflow,
        workflowable
      });
      controller.setup();
    },

    editWorkflow(workflow) {
      this.transitionToRoute(
        "adminPlugins.discourse-automation.workflows.show",
        workflow.id
      );
    }
  }
});
