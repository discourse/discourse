import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/overview.json");
  }
}
