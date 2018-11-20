export default Ember.Controller.extend({
  titleSorting: ["title"],
  emailTemplates: null,

  sortedTemplates: Ember.computed.sort("emailTemplates", "titleSorting")
});
