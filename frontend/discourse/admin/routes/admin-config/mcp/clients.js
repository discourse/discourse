import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpClientsRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/mcp/clients.json");
  }
}
