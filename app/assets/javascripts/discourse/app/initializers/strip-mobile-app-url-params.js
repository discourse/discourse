export default {
  name: "strip-mobile-app-url-params",

  initialize() {
    let queryStrings = window.location.search;

    if (queryStrings.indexOf("user_api_public_key") !== -1) {
      let params = queryStrings.startsWith("?")
        ? queryStrings.substr(1).split("&")
        : [];

      params = params.filter(param => {
        return (
          !param.startsWith("user_api_public_key=") &&
          !param.startsWith("auth_redirect=")
        );
      });

      queryStrings = params.length > 0 ? `?${params.join("&")}` : "";

      if (window.history && window.history.replaceState) {
        window.history.replaceState(
          null,
          null,
          `${location.pathname}${queryStrings}${location.hash}`
        );
      }
    }
  }
};
