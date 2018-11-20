import { defaultHomepage } from "discourse/lib/utilities";
import buildStaticRoute from "discourse/routes/build-static-route";

const ForgotPasswordRoute = buildStaticRoute("password-reset");

ForgotPasswordRoute.reopen({
  beforeModel() {
    const loginRequired = this.controllerFor("application").get(
      "loginRequired"
    );
    this.replaceWith(
      loginRequired ? "login" : `discovery.${defaultHomepage()}`
    ).then(e => {
      Ember.run.next(() => e.send("showForgotPassword"));
    });
  }
});

export default ForgotPasswordRoute;
