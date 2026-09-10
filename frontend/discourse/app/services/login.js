import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { findAll } from "discourse/models/login-method";
import { i18n } from "discourse-i18n";

@disableImplicitInjections
export default class LoginService extends Service {
  @service site;
  @service siteSettings;

  get isOnlyOneExternalLoginMethod() {
    return (
      !this.siteSettings.enable_local_logins &&
      this.externalLoginMethods.length === 1
    );
  }

  get externalLoginMethods() {
    return findAll();
  }

  get readOnlyLoginMessage() {
    return i18n(
      this.site.isStaffWritesOnly
        ? "staff_writes_only_mode.login_disabled"
        : "read_only_mode.login_disabled"
    );
  }

  get readOnlySignupMessage() {
    if (this.site.isStaffWritesOnly) {
      return i18n("staff_writes_only_mode.signup_disabled");
    }
    if (this.siteSettings.site_archived) {
      return i18n("site_archived.signup_disabled");
    }
    return i18n("read_only_mode.signup_disabled");
  }

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
}
