import DiscourseRoute from "discourse/routes/discourse";

export default class Group extends DiscourseRoute {
  titleToken() {
    return [this.modelFor("group").get("name")];
  }

  model(params) {
    return this.store.find("group", params.name);
  }

  serialize(model) {
    return { name: model.get("name").toLowerCase() };
  }
}
