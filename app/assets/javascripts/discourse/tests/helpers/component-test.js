import { setupRenderingTest as emberSetupRenderingTest } from "ember-qunit";
import { autoLoadModules } from "discourse/instance-initializers/auto-load-modules";
import { AUTO_GROUPS } from "discourse/lib/constants";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { currentSettings } from "discourse/tests/helpers/site-settings";

export function setupRenderingTest(hooks) {
  emberSetupRenderingTest(hooks);

  hooks.beforeEach(function () {
    if (!hooks.usingDiscourseModule) {
      this.siteSettings = currentSettings();
      this.registry ||= this.owner.__registry__;
      this.container = this.owner;
    }

    this.site = Site.current();
    this.session = Session.current();

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
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", currentUser, {
      instantiate: false,
    });

    this.owner.unregister("service:topic-tracking-state");
    this.owner.register(
      "service:topic-tracking-state",
      TopicTrackingState.create({ currentUser }),
      { instantiate: false }
    );

    autoLoadModules(this.owner, this.registry);
    this.owner.lookup("service:store");
  });
}
