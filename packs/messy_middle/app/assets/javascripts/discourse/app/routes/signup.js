import buildStaticRoute from "discourse/routes/build-static-route";
import { next } from "@ember/runloop";

const SignupRoute = buildStaticRoute("signup");

SignupRoute.reopen({
  beforeModel() {
    let canSignUp = this.controllerFor("application").get("canSignUp");

    if (!this.siteSettings.login_required) {
      this.replaceWith("discovery.latest").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    } else {
      this.replaceWith("login").then((e) => {
        if (canSignUp) {
          next(() => e.send("showCreateAccount"));
        }
      });
    }
  },
});

export default SignupRoute;
