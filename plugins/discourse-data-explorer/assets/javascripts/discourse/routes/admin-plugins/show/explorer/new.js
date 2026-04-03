import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerNew extends DiscourseRoute {
  model() {
    return { name: "", description: "" };
  }
}
