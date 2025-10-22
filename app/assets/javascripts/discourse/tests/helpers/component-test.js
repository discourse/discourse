import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { setupRenderingTest as emberSetupRenderingTest } from "ember-qunit";
import { autoLoadModules } from "discourse/instance-initializers/auto-load-modules";
import { AUTO_GROUPS } from "discourse/lib/constants";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { currentSettings } from "discourse/tests/helpers/site-settings";

class RouterStub extends Service {
  @tracked
  currentRoute = {
    attributes: { category: { id: 1, slug: "announcements" } },
  };
  @tracked currentRouteName = "discovery.latest";

  on() {}
  off() {}
}

export function setupRenderingTest(hooks, opts = {}) {
  emberSetupRenderingTest(hooks);

  opts.anonymous ??= false;
  opts.stubRouter ??= false;

  hooks.beforeEach(function () {
    if (!hooks.usingDiscourseModule) {
      this.siteSettings = currentSettings();
      this.registry ||= this.owner.__registry__;
      this.container = this.owner;
    }

    this.site = Site.current();
    this.session = Session.current();

    if (opts.stubRouter) {
      this.owner.unregister("service:router");
      this.owner.register("service:router", RouterStub);
    }

    this.owner.unregister("service:current-user");

    if (!opts.anonymous) {
      const currentUser = User.create({
        username: "eviltrout",
        name: "Robin Ward",
        admin: false,
        moderator: false,
        groups: [AUTO_GROUPS.trust_level_0, AUTO_GROUPS.trust_level_1],
        user_option: {
          timezone: "Australia/Brisbane",
        },
      });
      this.currentUser = currentUser;
      this.owner.register("service:current-user", currentUser, {
        instantiate: false,
      });

      this.owner.unregister("service:topic-tracking-state");
      this.owner.register(
        "service:topic-tracking-state",
        TopicTrackingState.create({ currentUser }),
        { instantiate: false }
      );
    }

    autoLoadModules(this.owner, this.registry);
    this.owner.lookup("service:store");
  });
}
