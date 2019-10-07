import ModalFunctionality from "discourse/mixins/modal-functionality";
import PlannablesMixin from "./plannables-mixin";

export default Ember.Controller.extend(PlannablesMixin, ModalFunctionality, {
  plan: null,
  formErrors: null,

  addPlanDisabled: Ember.computed.empty("plan.identifier"),

  setup() {
    this.fetchPlannables();
  },

  onClose() {
    this.setProperties({
      plan: null,
      formErrors: null
    });
  },

  onShow() {
    this.set("formErrors", null);
  },

  plannable: Ember.computed("plannables.[]", "plan.identifier", function() {
    if (!this.plan.identifier) return;
    return this.plannables.findBy("id", this.plan.identifier);
  }),

  actions: {
    onChangeField(name, value) {
      Ember.set(this.plan.options, name, value);
    },

    onSelectPlan(identifier) {
      this.set("formErrors", null);
      this.plan.set("identifier", identifier);

      const options = Ember.Object.create();
      Object.keys(this.plannable.fields).forEach(k => {
        const field = this.plannable.fields[k];
        options[k] = {
          value: field.default,
          use_provided: false
        };
      });
      this.plan.set("options", options);
    },

    savePlan() {
      this.set("formErrors", null);
      this.plan
        .save(
          JSON.parse(
            JSON.stringify(
              this.plan.getProperties(
                "identifier",
                "options",
                "workflow_id",
                "delay"
              )
            )
          )
        )
        .catch(error => {
          if (error.jqXHR && error.jqXHR.status === 422) {
            const errors = error.jqXHR.responseJSON.errors;
            this.set("formErrors", errors);
          }
        })
        .then(result => {
          if (result) {
            this.send("closeModal");
            this.onComplete && this.onComplete();
          }
        });
    }
  }
});
