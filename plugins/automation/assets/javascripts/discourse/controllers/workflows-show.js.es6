import showModal from "discourse/lib/show-modal";

const MUTABLE_PROPERTIES = ["name"];

export default Ember.Controller.extend({
  workflowChanged: false,
  formErrors: null,

  availablePlaceholders: Ember.computed(
    "model.trigger.availablePlaceholders",
    function() {
      return this.model.trigger.availablePlaceholders.map(x => `%${x}%`);
    }
  ),

  triggerHasOptions: Ember.computed("model.trigger.options", function() {
    return Object.keys(this.model.trigger.options).length;
  }),

  actions: {
    onWorkflowNameChanged(event) {
      this.setProperties({
        workflowChanged: true,
        "model.name": event.target.value
      });
    },

    destroyTrigger(trigger) {
      return bootbox.confirm(
        I18n.t("discourse_automation.trigger.confirm_destroy"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            trigger
              .destroyRecord({
                id: trigger.id,
                workflow_id: this.model.id
              })
              .then(() => this.send("triggerRefresh"));
          }
        }
      );
    },

    addTrigger() {
      const controller = showModal("add-trigger");

      const trigger = this.store.createRecord("trigger", {
        workflow_id: this.model.id
      });

      controller.setProperties({
        trigger,
        onComplete: Ember.run.bind(this, () =>
          this.model.set("trigger", trigger)
        )
      });
      controller.setup();
    },

    editTrigger(trigger) {
      const controller = showModal("edit-trigger");
      controller.setProperties({
        workflow: this.model,
        trigger
      });
      controller.setup();
    },

    editPlan(plan) {
      const controller = showModal("edit-plan");
      controller.setProperties({ workflow: this.model, plan });
      controller.setup();
    },

    destroyPlan(plan) {
      return bootbox.confirm(
        I18n.t("discourse_automation.plan.confirm_destroy"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            plan.destroyRecord().then(() => this.send("triggerRefresh"));
          }
        }
      );
    },

    addPlan() {
      const controller = showModal("add-plan");

      const plan = this.store.createRecord("plan", {
        workflow_id: this.model.id
      });

      controller.setProperties({
        plan,
        onComplete: Ember.run.bind(this, () =>
          this.model.plans.pushObject(plan)
        )
      });
      controller.setup();
    },

    saveWorkflow() {
      this.set("formErrors", null);

      this.store
        .update(
          "workflow",
          this.model.id,
          this.model.getProperties(MUTABLE_PROPERTIES)
        )
        .catch(error => {
          if (error.jqXHR && error.jqXHR.status === 422) {
            const errors = error.jqXHR.responseJSON.errors;
            this.set("formErrors", errors);
          }
        })
        .then(result => {
          if (result) {
            this.set("workflowChanged", false);
            this.send("triggerRefresh");
          }
        });
    },

    destroyWorkflow() {
      return bootbox.confirm(
        I18n.t("discourse_automation.workflows.confirm_destroy"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            this.model
              .destroyRecord()
              .then(() =>
                this.transitionToRoute(
                  "adminPlugins.discourse-automation.workflows"
                )
              );
          }
        }
      );
    }
  }
});
