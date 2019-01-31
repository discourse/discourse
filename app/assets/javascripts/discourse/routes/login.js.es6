import buildStaticRoute from "discourse/routes/build-static-route";
import { defaultHomepage } from "discourse/lib/utilities";

const LoginRoute = buildStaticRoute("login");

LoginRoute.reopen({
  beforeModel() {
    if (!this.siteSettings.login_required) {
      this.replaceWith(`/${defaultHomepage()}`).then(e => {
        Ember.run.next(() => e.send("showLogin"));
      });
    }
  }
});

export default LoginRoute;
