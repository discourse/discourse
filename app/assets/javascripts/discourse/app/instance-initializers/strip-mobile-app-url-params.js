export default {
  initialize() {
    let queryStrings = window.location.search;

    if (queryStrings.includes("user_api_public_key")) {
      let params = queryStrings.startsWith("?")
        ? queryStrings.slice(1).split("&")
        : [];

      params = params.filter((param) => {
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
  },
};
