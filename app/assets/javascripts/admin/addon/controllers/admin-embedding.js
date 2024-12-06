import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminEmbeddingController extends Controller {
  @service router;
  get showHeader() {
    return [
      "adminEmbedding.crawlers",
      "adminEmbedding.index",
      "adminEmbedding.postsAndTopics",
      "adminEmbedding.settings",
    ].includes(this.router.currentRouteName);
  }
}
