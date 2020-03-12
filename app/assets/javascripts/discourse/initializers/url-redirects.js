import DiscourseURL from "discourse/lib/url";

export default {
  name: "url-redirects",
  after: "inject-objects",

  initialize(container) {
    const currentUser = container.lookup("current-user:main");

    // URL rewrites (usually due to refactoring)
    DiscourseURL.rewrite(/^\/category\//, "/c/");
    DiscourseURL.rewrite(/^\/group\//, "/groups/");
    DiscourseURL.rewrite(/^\/groups$/, "/g");
    DiscourseURL.rewrite(/^\/groups\//, "/g/");
    DiscourseURL.rewrite(/\/private-messages\/$/, "/messages/");
    DiscourseURL.rewrite(/^\/users$/, "/u");
    DiscourseURL.rewrite(/^\/users\//, "/u/");
    DiscourseURL.rewrite(/\/admin\/flags/, "/review");

    if (currentUser) {
      const username = currentUser.get("username");
      DiscourseURL.rewrite(
        new RegExp(`^/u/${username}/?$`, "i"),
        `/u/${username}/activity`
      );
    }

    DiscourseURL.rewrite(/^\/u\/([^\/]+)\/?$/, "/u/$1/summary", {
      exceptions: [
        "/u/account-created",
        "/users/account-created",
        "/u/password-reset",
        "/users/password-reset"
      ]
    });
  }
};
