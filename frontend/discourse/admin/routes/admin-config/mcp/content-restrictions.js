import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpContentRestrictionsRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/content-restrictions.json");
  }
}
