import DiscourseURL from "discourse/lib/url";
import { initializeDefaultHomepage } from "discourse/lib/utilities";
import escapeRegExp from "discourse-common/utils/escape-regexp";

export default {
  name: "url-redirects",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (currentUser) {
      const username = currentUser.get("username");
      const escapedUsername = escapeRegExp(username);
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
    let siteSettings = container.lookup("service:site-settings");
    initializeDefaultHomepage(siteSettings);

    const defaultUserRoute = `/u/$1/${
      siteSettings.view_user_route || "summary"
    }`;

    DiscourseURL.rewrite(/^\/u\/([^\/]+)\/?$/, defaultUserRoute, {
      exceptions: [
        "/u/account-created",
        "/users/account-created",
        "/u/password-reset",
        "/users/password-reset",
      ],
    });
  },
};
