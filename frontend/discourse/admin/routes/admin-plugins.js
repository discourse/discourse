import AdminPlugin from "discourse/admin/models/admin-plugin";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsRoute extends DiscourseRoute {
  async model() {
    const plugins = await this.store.findAll("plugin");
    return plugins.content.map((plugin) => AdminPlugin.create(plugin));
  }

  titleToken() {
    return i18n("admin.plugins.title");
  }
}
