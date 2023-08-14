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
      debugger;
      router.one("didTransition", () => {
        next(() => {
          const lookupPath =
            router.currentPath === "invites.show"
              ? "controller:invites-show"
              : "component:login";
          owner
            .lookup(lookupPath)
            .authenticationComplete(JSON.parse(lastAuthResult));
        });
      });
    }
  },
};
