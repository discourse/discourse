import { service } from "@ember/service";
import SharedAiArtifacts from "./shared-ai-artifacts";

export default class UserActivitySharedArtifacts extends SharedAiArtifacts {
  @service router;

  beforeModel() {
    const redirect = super.beforeModel(...arguments);
    if (redirect) {
      return redirect;
    }
    return this.router.replaceWith("userActivity.sharedAiArtifacts");
  }
}
