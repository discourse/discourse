import { next } from "@ember/runloop";

export default {
  after: "inject-objects",
  initialize(owner) {
    let lastAuthResult;

    if (document.getElementById("data-authentication")) {
      // Happens for full screen logins
      lastAuthResult = document.getElementById("data-authentication").dataset
        .authenticationData;
    }

    if (lastAuthResult) {
      const router = owner.lookup("router:main");

      router.one("didTransition", () => {
        const controllerName =
          router.currentPath === "invites.show" ? "invites-show" : "login";

        next(() => {
          let controller = owner.lookup(`controller:${controllerName}`);
          controller.authenticationComplete(JSON.parse(lastAuthResult));
        });
      });
    }
  },
};
