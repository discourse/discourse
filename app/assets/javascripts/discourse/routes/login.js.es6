import buildStaticRoute from "discourse/routes/build-static-route";

const LoginRoute = buildStaticRoute("login");

LoginRoute.reopen({
  beforeModel() {
    if (!this.siteSettings.login_required) {
      this.replaceWith("discovery.latest").then(e => {
        Ember.run.next(() => e.send("showLogin"));
      });
    }
  }
});

export default LoginRoute;
