import Controller, { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),
  tagGroups: controller(),

  actions: {
    onSave() {
      const tagGroups = this.tagGroups.model;
      tagGroups.pushObject(this.model);

      this.router.transitionTo("tagGroups.index");
    },
  },
});
