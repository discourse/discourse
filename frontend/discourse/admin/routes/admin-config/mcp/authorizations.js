import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpAuthorizationsRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/authorizations.json");
  }
}
