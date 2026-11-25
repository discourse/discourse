import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";

export default class WorkflowsFormRoute extends DiscourseRoute {
  async model(params, transition) {
    try {
      return await ajax(
        `/workflows/form/${params.uuid}.json${window.location.search || ""}`
      );
    } catch (error) {
      if (
        this.currentUser ||
        error.jqXHR?.responseJSON?.error_type !== "not_logged_in"
      ) {
        throw error;
      }

      // The login route returns to window.location, which is still the previous page here.
      if (transition.from) {
        DiscourseURL.redirectTo(transition.intent.url);
        return new Promise(() => {});
      }

      transition.send("showLogin");
      // Show the error page in embed mode, where showLogin opens a popup instead of transitioning.
      throw error;
    }
  }
}
