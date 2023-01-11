import { setDefaultOwner } from "discourse-common/lib/get-owner";
import User from "discourse/models/user";
import Site from "discourse/models/site";
import deprecated from "discourse-common/lib/deprecated";

export default {
  name: "inject-objects",
  after: "export-application-global",
  initialize(container, app) {
    // This is required for Ember CLI tests to work
    setDefaultOwner(app.__container__);

    Object.defineProperty(app, "SiteSettings", {
      get() {
        deprecated(
          `use injected siteSettings instead of Discourse.SiteSettings`,
          {
            since: "2.8",
            dropFrom: "2.9",
            id: "discourse.global.site-settings",
          }
        );
        return container.lookup("service:site-settings");
      },
    });
    Object.defineProperty(app, "User", {
      get() {
        deprecated(
          `import discourse/models/user instead of using Discourse.User`,
          {
            since: "2.8",
            dropFrom: "2.9",
            id: "discourse.global.user",
          }
        );
        return User;
      },
    });
    Object.defineProperty(app, "Site", {
      get() {
        deprecated(
          `import discourse/models/site instead of using Discourse.Site`,
          {
            since: "2.8",
            dropFrom: "2.9",
            id: "discourse.global.site",
          }
        );
        return Site;
      },
    });
  },
};
