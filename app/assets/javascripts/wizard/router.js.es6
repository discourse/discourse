import getUrl from "discourse-common/lib/get-url";
import ENV from "discourse-common/config/environment";

const Router = Ember.Router.extend({
  rootURL: getUrl("/wizard/"),
  location: ENV.environment === "test" ? "none" : "history"
});

Router.map(function() {
  this.route("step", { path: "/steps/:step_id" });
});

export default Router;
