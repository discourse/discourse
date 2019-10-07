import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  plan: null,
  formErrors: null,

  onShow() {
    this.set("formErrors", null);
  },

  setup() {},

  plannable: Ember.computed.readOnly("plan.plannable"),

  actions: {
    onChangeField(name, value) {
      Ember.set(this.plan.options, name, value);
    },

    updatePlan() {
      this.set("formErrors", null);

      this.plan
        .update({
          workflow_id: this.workflow.id,
          identifier: this.plan.identifier,
          delay: this.plan.delay,
          options: JSON.parse(JSON.stringify(this.plan.options))
        })
        .catch(error => {
          if (error.jqXHR && error.jqXHR.status === 422) {
            const errors = error.jqXHR.responseJSON.errors;
            this.set("formErrors", errors);
          }
        })
        .then(result => {
          if (result) {
            this.send("closeModal");
          }
        });
    }
  }
});
