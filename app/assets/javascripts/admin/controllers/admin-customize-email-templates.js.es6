import Controller from "@ember/controller";
export default Controller.extend({
  emailTemplates: null,
  sortedTemplates: Ember.computed.sort("emailTemplates", "titleSorting"),

  init() {
    this._super(...arguments);

    this.titleSorting = ["title"];
  },

  actions: {
    selectTemplate(template) {
      this.transitionToRoute("adminCustomizeEmailTemplates.edit", template);
    }
  }
});
