import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpCapabilitiesRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/capabilities.json");
  }
}
