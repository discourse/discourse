import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  titleToken() {
    return [this.modelFor("group").get("name")];
  },

  model(params) {
    return this.store.find("group", params.name);
  },

  serialize(model) {
    return { name: model.get("name").toLowerCase() };
  },

  setupController(controller, model) {
    controller.setProperties({ model });
  }
});
