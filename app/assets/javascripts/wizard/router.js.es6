import getUrl from "discourse-common/lib/get-url";

const Router = Ember.Router.extend({
  rootURL: getUrl("/wizard/"),
  location: Ember.testing ? "none" : "history"
});

Router.map(function() {
  this.route("step", { path: "/steps/:step_id" });
});

export default Router;
