import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params, transition) {
    const path = params.path;
    return ajax("/permalink-check.json", {
      data: { path }
    }).then(results => {
      if (results.found) {
        // Avoid polluting the history stack for external links
        transition.abort();
        DiscourseURL.routeTo(results.target_url);
        return "";
      } else {
        // 404 body HTML
        return results.html;
      }
    });
  }
});
