import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminEmailPreviewDigestLegacyRoute extends Route {
  @service router;

  beforeModel(transition) {
    return this.router.replaceWith("adminEmail.previewDigest", {
      queryParams: transition.to.queryParams,
    });
  }
}
