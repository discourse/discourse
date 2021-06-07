import DiscourseURL from "discourse/lib/url";
import { initializeDefaultHomepage } from "discourse/lib/utilities";

export default {
  name: "url-redirects",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");
    if (currentUser) {
      const username = currentUser.get("username");
      const escapedUsername = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      DiscourseURL.rewrite(
        new RegExp(`^/u/${escapedUsername}/?$`, "i"),
        `/u/${username}/activity`
      );
    }

    // We are still using these for now
    DiscourseURL.rewrite(/^\/group\//, "/groups/");
    DiscourseURL.rewrite(/^\/groups$/, "/g");
    DiscourseURL.rewrite(/^\/groups\//, "/g/");

    // Initialize default homepage
    let siteSettings = container.lookup("site-settings:main");
    initializeDefaultHomepage(siteSettings);

    DiscourseURL.rewrite(/^\/u\/([^\/]+)\/?$/, "/u/$1/summary", {
      exceptions: [
        "/u/account-created",
        "/users/account-created",
        "/u/password-reset",
        "/users/password-reset",
      ],
    });
  },
};
