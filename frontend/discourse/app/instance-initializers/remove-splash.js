import { removeSplashScreen } from "discourse/lib/splash-screen";

export default {
  initialize(owner) {
    owner
      .lookup("service:router")
      .one("routeDidChange", () => removeSplashScreen());
  },
};
