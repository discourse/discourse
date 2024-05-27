import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL, { rewritePath } from "discourse/lib/url";
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

    const permalinkResults = await ajax("/permalink-check.json", {
      data: { path },
    });

    if (permalinkResults.found) {
      // Avoid polluting the history stack for external links
      transition.abort();

      let url = permalinkResults.target_url;

      if (transition._discourse_anchor) {
        // Remove the anchor from the permalink if present
        url = url.split("#")[0];

        // Add the anchor from the transition
        url += `#${transition._discourse_anchor}`;
      }

      DiscourseURL.routeTo(url);
      return "";
    } else {
      // 404 body HTML
      return permalinkResults.html;
    }
  }
}
