export default {
  initialize() {
    const params = new URLSearchParams(window.location.search);
    if (params.get("safe_mode")?.split(",").includes("deprecation_errors")) {
      window.EmberENV.RAISE_ON_DEPRECATION = true;
      return;
    }
  },
};
