import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminEmbeddingController extends Controller {
  @service router;
  get showHeader() {
    return [
      "adminEmbedding.index",
      "adminEmbedding.settings",
      "adminEmbedding.crawler_settings",
    ].includes(this.router.currentRouteName);
  }
}
