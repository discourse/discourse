import EmberRouter from "@ember/routing/router";
import getUrl from "discourse-common/lib/get-url";
import { isTesting } from "discourse-common/config/environment";

const Router = EmberRouter.extend({
  rootURL: getUrl("/wizard/"),
  location: isTesting() ? "none" : "history"
});

Router.map(function() {
  this.route("step", { path: "/steps/:step_id" });
});

export default Router;
