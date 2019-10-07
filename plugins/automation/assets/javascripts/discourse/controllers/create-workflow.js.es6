import ModalFunctionality from "discourse/mixins/modal-functionality";
import TriggerablesMixin from "./triggerables-mixin";
import PlannablesMixin from "./plannables-mixin";

export default Ember.Controller.extend(
  PlannablesMixin,
  TriggerablesMixin,
  ModalFunctionality,
  {
    trigger: null,
    plans: null,
    name: null,

    onClose() {
      this.setProperties({
        plan: null,
        trigger: null,
        workflow: null,
        workflowable: null
      });
    },

    triggerable: Ember.computed(
      "triggerables.[]",
      "workflowable.trigger",
      function() {
        if (!this.triggerables) return;
        if (!this.workflowable.trigger) return;

        return this.triggerables.findBy(
          "id",
          this.workflowable.trigger.identifier
        );
      }
    ),

    plannables: Ember.computed(
      "triggerables.[]",
      "workflowable.trigger",
      function() {
        if (!this.triggerables) return;
        if (!this.workflowable.trigger) return;

        return this.triggerables.findBy(
          "id",
          this.workflowable.trigger.identifier
        );
      }
    ),

    setup() {
      if (this.workflowable.trigger) {
        this.set(
          "trigger",
          this.store.createRecord("trigger", {
            identifier: this.workflowable.trigger.identifier
          })
        );
      }

      this.fetchTriggerables();
      this.fetchPlannables().then(plannables => {
        const plans = (this.workflowable.plans || []).map(plan => {
          const plannable = plannables.findBy("id", plan.identifier);
          plan = this.store.createRecord("plan", plan);
          return { plannable, plan };
        });

        this.set("plans", plans);
      });
    },

    saveTrigger(workflow) {
      this.trigger.set("workflow_id", workflow.id);

      return this.trigger
        .save(
          JSON.parse(
            JSON.stringify(
              this.trigger.getProperties("identifier", "workflow_id", "options")
            )
          )
        )
        .catch(error => {
          if (error.jqXHR && error.jqXHR.status === 422) {
            const errors = error.jqXHR.responseJSON.errors;
            this.set("formErrors", errors);
          }
        })
        .then(triggerResult => {
          if (triggerResult) {
            return {
              trigger: triggerResult.responseJson.trigger,
              workflow
            };
          } else {
            throw "test";
          }
        });
    },

    savePlans(r) {
      this.plans.forEach(plan => {
        plan.set("workflow_id", r.workflow.id);

        plan.plan
          .save(
            JSON.parse(
              JSON.stringify(
                plan.plan.getProperties(
                  "identifier",
                  "options",
                  "workflow_id",
                  "delay"
                )
              )
            )
          )
          .then(result => {
            if (result) {
              this.send("closeModal");
              this.transitionToRoute(
                "adminPlugins.discourse-automation.workflows.show",
                r.workflow.id
              );
            }
          });
      });
    },

    actions: {
      onChangeField(name, value) {
        Ember.set(this.trigger.options, name, value);
      },

      saveWorkflow() {
        this.workflow
          .save({ name: this.name })
          .then(result => {
            if (result) {
              return result.responseJson.workflow;
            } else {
              throw "test";
            }
          })
          .then(workflow => {
            if (this.workflowable.trigger) {
              this.saveTrigger(workflow).then(r => this.savePlans(r));
            } else {
              this.send("closeModal");
              this.transitionToRoute(
                "adminPlugins.discourse-automation.workflows.show",
                workflow.id
              );
            }
          })
          .catch(e => console.log(e))
          .finally(() => this.set("name", null));
      }
    }
  }
);
