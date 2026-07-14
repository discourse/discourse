export default {
  initialize(owner) {
    owner
      .lookup("service:router")
      .one("routeDidChange", () =>
        document.querySelector("#d-splash")?.remove()
      );
  },
};
