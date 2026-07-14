import config from "discourse/config/environment";

export default {
  initialize() {
    const params = new URLSearchParams(window.location.search);
    if (params.get("safe_mode")?.split(",").includes("deprecation_errors")) {
      config.RAISE_ON_DEPRECATION = true;
      return;
    }
  },
};
