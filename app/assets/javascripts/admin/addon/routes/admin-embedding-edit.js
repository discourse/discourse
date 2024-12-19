import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingEditRoute extends DiscourseRoute {
  async model(params) {
    const embedding = await this.store.find("embedding");
    return embedding.embeddable_hosts.find((host) => host.id === parseInt(params.id, 10));
  }

  titleToken() {
    return i18n("admin.embedding.host_form.edit_header");
  }
}
