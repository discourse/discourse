import { sort } from "@ember/object/computed";
import { action } from "@ember/object";
import Controller from "@ember/controller";

export default Controller.extend({
  sortedTemplates: sort("emailTemplates", "titleSorting"),

  init() {
    this._super(...arguments);

    this.set("titleSorting", ["title"]);
  },

  @action
  onSelectTemplate(template) {
    this.transitionToRoute("adminCustomizeEmailTemplates.edit", template);
  }
});
