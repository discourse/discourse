import { lookup } from "discourse/lib/service";
import DiscourseURL from "discourse/lib/url";
import { initializeDefaultHomepage } from "discourse/lib/utilities";
import CurrentUserService from "discourse/services/current-user";
import SiteSettingsService from "discourse/services/site-settings";

export default {
  after: "inject-objects",

  initialize(owner) {
    // We are still using these for now
    DiscourseURL.rewrite(/^\/group\//, "/groups/");
    DiscourseURL.rewrite(/^\/groups$/, "/g");
    DiscourseURL.rewrite(/^\/groups\//, "/g/");

    const currentUser = lookup(owner, CurrentUserService);
    let siteSettings = lookup(owner, SiteSettingsService);

    // Setup `/my` redirects
    if (currentUser) {
      DiscourseURL.rewrite(/^\/my\//, `/u/${currentUser.username_lower}/`);
    } else {
      DiscourseURL.rewrite(/^\/my\/.*/, "/login-preferences");
    }

    initializeDefaultHomepage(siteSettings);
  },
};
