import ModalFunctionality from "discourse/mixins/modal-functionality";
import TriggerablesMixin from "./triggerables-mixin";

export default Ember.Controller.extend(TriggerablesMixin, ModalFunctionality, {
  trigger: null,
  workflow: null,
  formErrors: null,
  triggerParams: null,

  setup() {
    this.set("triggerParams", {
      key: this.trigger.key,
      options: this.trigger.options
    });
  },

  onShow() {
    this.fetchAvailableTriggers();

    this.setProperties({
      formErrors: null
    });
  },

  onClose() {
    this.setProperties({
      trigger: null,
      workflow: null,
      triggerParams: null,
      formErrors: null
    });
  },

  triggerable: Ember.computed.readOnly("trigger.triggerable"),

  actions: {
    onChangeField(name, value) {
      Ember.set(this.triggerParams.options, name, value);
    },

    saveTrigger() {
      this.set("formErrors", null);

      this.trigger &&
        this.trigger
          .save({
            workflow_id: this.workflow.id,
            key: this.triggerParams.key,
            options: JSON.parse(JSON.stringify(this.triggerParams.options))
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
              this.onComplete && this.onComplete();
            }
          });
    }
  }
});
