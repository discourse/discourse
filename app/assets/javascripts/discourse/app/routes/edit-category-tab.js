import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    const model = this.modelFor("editCategory");
    model.set("params.tab", params.tab);
    return model;
  },
});
