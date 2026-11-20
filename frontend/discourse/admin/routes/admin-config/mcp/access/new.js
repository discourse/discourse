import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpAccessNewRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminConfig.mcp.access");
  }
}
