import RestModel from "discourse/models/rest";

const ATTRIBUTES = ["name", "script", "fields", "trigger", "id"];

const Automation = RestModel.extend({
  updateProperties() {
    return {
      id: this.id,
      name: this.name,
      fields: this.fields,
      script: this.script.id,
      trigger: {
        id: this.trigger.id,
        name: this.trigger.name,
        metadata: {
          group_ids: this.trigger.metadata.group_ids,
          execute_at: this.trigger.metadata.execute_at
        }
      }
    };
  },

  createProperties() {
    return this.getProperties(ATTRIBUTES);
  }
});

export default Automation;
