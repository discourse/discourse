import DiscourseURL from "discourse/lib/url";
import { initializeDefaultHomepage } from "discourse/lib/utilities";

export default {
  after: "inject-objects",

  initialize(owner) {
    // We are still using these for now
    DiscourseURL.rewrite(/^\/group\//, "/groups/");
    DiscourseURL.rewrite(/^\/groups$/, "/g");
    DiscourseURL.rewrite(/^\/groups\//, "/g/");

    const currentUser = owner.lookup("service:current-user");
    let siteSettings = owner.lookup("service:site-settings");

    // Setup `/my` redirects
    if (currentUser) {
      DiscourseURL.rewrite(/^\/my\//, `/u/${currentUser.username_lower}/`);
    } else {
      DiscourseURL.rewrite(/^\/my\/.*/, "/login-preferences");
    }

    initializeDefaultHomepage(siteSettings);
  },
};
