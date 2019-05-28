export default Ember.Controller.extend({
  emailTemplates: null,
  sortedTemplates: Ember.computed.sort("emailTemplates", "titleSorting"),

  init() {
    this._super(...arguments);

    this.titleSorting = ["title"];
  }
});
