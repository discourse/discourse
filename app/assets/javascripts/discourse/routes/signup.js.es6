import buildStaticRoute from "discourse/routes/build-static-route";

const SignupRoute = buildStaticRoute("signup");

SignupRoute.reopen({
  beforeModel() {
    var canSignUp = this.controllerFor("application").get("canSignUp");

    if (!this.siteSettings.login_required) {
      this.replaceWith("discovery.latest").then(e => {
        if (canSignUp) {
          Ember.run.next(() => e.send("showCreateAccount"));
        }
      });
    } else {
      this.replaceWith("login").then(e => {
        if (canSignUp) {
          Ember.run.next(() => e.send("showCreateAccount"));
        }
      });
    }
  }
});

export default SignupRoute;
