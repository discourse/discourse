import { next } from "@ember/runloop";
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
      next(() => e.send("showForgotPassword"));
    });
  }
});

export default ForgotPasswordRoute;
