import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { findAll } from "discourse/models/login-method";

@disableImplicitInjections
export default class LoginService extends Service {
  @service siteSettings;

  @action
  async externalLogin(
    loginMethod,
    { signup = false, setLoggingIn = null } = {}
  ) {
    try {
      setLoggingIn?.(true);
      await loginMethod.doLogin({ signup });
    } catch {
      setLoggingIn?.(false);
    }
  }

  @action
  async singleExternalLogin(opts) {
    await this.externalLogin(this.externalLoginMethods[0], opts);
  }

  get isOnlyOneExternalLoginMethod() {
    return (
      !this.siteSettings.enable_local_logins &&
      this.externalLoginMethods.length === 1
    );
  }

  get externalLoginMethods() {
    return findAll();
  }
}
