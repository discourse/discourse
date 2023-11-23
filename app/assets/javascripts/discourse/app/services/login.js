import { action } from "@ember/object";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class LoginService extends Service {
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
}
