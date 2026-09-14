import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpActivityRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/activity.json");
  }
}
