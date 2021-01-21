import Controller from "@ember/controller";
import { action } from "@ember/object";
import { sort } from "@ember/object/computed";

export default Controller.extend({
  sortedTemplates: sort("emailTemplates", "titleSorting"),

  init() {
    this._super(...arguments);

    this.set("titleSorting", ["title"]);
  },

  @action
  onSelectTemplate(template) {
    this.transitionToRoute("adminCustomizeEmailTemplates.edit", template);
  },
});
