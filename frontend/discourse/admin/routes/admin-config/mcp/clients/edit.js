import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigMcpClientEditRoute extends DiscourseRoute {
  model({ id }) {
    return ajax(`/admin/mcp/clients/${id}.json`);
  }

  titleToken() {
    return i18n("admin.config.mcp.clients.edit");
  }
}
