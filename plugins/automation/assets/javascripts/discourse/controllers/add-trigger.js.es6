import ModalFunctionality from "discourse/mixins/modal-functionality";
import TriggerablesMixin from "./triggerables-mixin";

export default Ember.Controller.extend(TriggerablesMixin, ModalFunctionality, {
  formErrors: null,
  trigger: null,
  addTriggerDisabled: Ember.computed.empty("trigger.identifier"),

  setup() {
    this.fetchTriggerables();
  },

  onShow() {
    this.set("formErrors", null);
  },

  onClose() {
    this.setProperties({
      trigger: null,
      formErrors: null
    });
  },

  triggerable: Ember.computed(
    "triggerables.[]",
    "trigger.identifier",
    function() {
      if (!this.trigger.identifier) return;
      return this.triggerables.findBy("id", this.trigger.identifier);
    }
  ),

  actions: {
    onChangeField(name, value) {
      Ember.set(this.trigger.options, name, value);
    },

    onSelectTrigger(identifier) {
      this.set("formErrors", null);
      this.trigger.set("identifier", identifier);

      const options = Ember.Object.create();
      Object.keys(this.triggerable.fields).forEach(k => {
        const field = this.triggerable.fields[k];
        options[k] = {
          value: field.default
        };
      });
      this.trigger.set("options", options);
    },

    saveTrigger() {
      this.set("formErrors", null);

      this.trigger
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
        .then(result => {
          if (result) {
            this.send("closeModal");
            this.onComplete && this.onComplete();
          }
        });
    }
  }
});
