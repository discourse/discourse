import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpAccessRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/access.json");
  }
}
