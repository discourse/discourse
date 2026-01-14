import deprecated from "discourse/lib/deprecated";
import { setDefaultOwner } from "discourse/lib/get-owner";
import Site from "discourse/models/site";
import User from "discourse/models/user";

export default {
  after: "sniff-capabilities",

  initialize(owner) {
    // This is required for Ember CLI tests to work
    setDefaultOwner(owner.__container__);

    window.Discourse = owner;

    Object.defineProperty(owner, "SiteSettings", {
      get() {
        deprecated(
          `use injected siteSettings instead of Discourse.SiteSettings`,
          {
            since: "2.8",
            dropFrom: "3.2",
            id: "discourse.global.site-settings",
          }
        );
        return owner.lookup("service:site-settings");
      },
    });
    Object.defineProperty(owner, "User", {
      get() {
        deprecated(
          `import discourse/models/user instead of using Discourse.User`,
          {
            since: "2.8",
            dropFrom: "3.2",
            id: "discourse.global.user",
          }
        );
        return User;
      },
    });
    Object.defineProperty(owner, "Site", {
      get() {
        deprecated(
          `import discourse/models/site instead of using Discourse.Site`,
          {
            since: "2.8",
            dropFrom: "3.2",
            id: "discourse.global.site",
          }
        );
        return Site;
      },
    });
  },

  teardown() {
    delete window.Discourse;
  },
};
