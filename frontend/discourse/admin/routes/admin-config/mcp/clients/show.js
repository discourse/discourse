import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigMcpClientRoute extends DiscourseRoute {
  model({ id }) {
    return ajax(`/admin/mcp/clients/${id}.json`);
  }
}
