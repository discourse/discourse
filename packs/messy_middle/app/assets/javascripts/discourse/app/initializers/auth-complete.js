import { next } from "@ember/runloop";
export default {
  name: "auth-complete",
  after: "inject-objects",
  initialize(container) {
    let lastAuthResult;

    if (document.getElementById("data-authentication")) {
      // Happens for full screen logins
      lastAuthResult = document.getElementById("data-authentication").dataset
        .authenticationData;
    }

    if (lastAuthResult) {
      const router = container.lookup("router:main");

      router.one("didTransition", () => {
        const controllerName =
          router.currentPath === "invites.show" ? "invites-show" : "login";

        next(() => {
          let controller = container.lookup(`controller:${controllerName}`);
          controller.authenticationComplete(JSON.parse(lastAuthResult));
        });
      });
    }
  },
};
