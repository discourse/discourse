import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    let model = this.modelFor("editChildCategory");
    model.set("params.tab", params.tab);
    return model;
  },

  renderTemplate() {
    this.render("edit-category-tab", {
      controller: "edit-category-tab",
      model: this.currentModel,
    });
  },
});
