import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return this.modelFor("editChildCategory");
  },

  renderTemplate() {
    this.render("edit-category-tabs", {
      controller: "edit-category-tabs",
      model: this.currentModel,
    });

    this.controllerFor("editCategory.tabs").set(
      "parentParams",
      this.paramsFor("editChildCategory")
    );
  },
});
