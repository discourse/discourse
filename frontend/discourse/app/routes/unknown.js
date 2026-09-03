import { service } from "@ember/service";
import resolvePermalink from "discourse/lib/permalink-check";
import { rewritePath } from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class UnknownRoute extends DiscourseRoute {
  @service router;

  async model(_, transition) {
    const path = transition.intent.url;

    if (!this.currentUser && this.siteSettings.login_required) {
      return;
    }

    const rewrittenPath = path && rewritePath(path);
    if (rewrittenPath !== path) {
      this.router.transitionTo(rewrittenPath);
      return;
    }

    const result = await resolvePermalink(path, transition);
    // 404 body HTML, unless the permalink redirect already took over
    return result.type === "redirect" ? "" : result.html;
  }
}
