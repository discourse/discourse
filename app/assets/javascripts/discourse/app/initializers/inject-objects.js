import { setDefaultOwner } from "discourse-common/lib/get-owner";
import { isLegacyEmber } from "discourse-common/config/environment";
import User from "discourse/models/user";
import deprecated from "discourse-common/lib/deprecated";

export default {
  name: "inject-objects",
  initialize(container, app) {
    // This is required for Ember CLI tests to work
    setDefaultOwner(app.__container__);

    // Backwards compatibility for Discourse.SiteSettings and Discourse.User
    if (!isLegacyEmber()) {
      app.yolo = "abc";
      Object.defineProperty(app, "SiteSettings", {
        get() {
          deprecated(
            `use injected siteSettings instead of Discourse.SiteSettings`,
            {
              since: "2.8",
              dropFrom: "2.9",
            }
          );
          return container.lookup("site-settings:main");
        },
      });
      Object.defineProperty(app, "User", {
        get() {
          deprecated(
            `import discourse/models/user instead of using Discourse.User`,
            {
              since: "2.8",
              dropFrom: "2.9",
            }
          );
          return User;
        },
      });
    }
  },
};
