import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowWireframeDesignsRoute extends DiscourseRoute {
  async model() {
    const { designs } = await ajax("/admin/plugins/wireframe/designs.json");
    return designs;
  }

  titleToken() {
    return i18n("wireframe.admin.designs.title");
  }
}
