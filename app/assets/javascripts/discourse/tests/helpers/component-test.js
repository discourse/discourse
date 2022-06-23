import { render } from "@ember/test-helpers";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { autoLoadModules } from "discourse/initializers/auto-load-modules";
import QUnit, { test } from "qunit";

export { setupRenderingTest } from "ember-qunit";

export default function (name, opts) {
  opts = opts || {};

  if (opts.skip) {
    return;
  }

  if (typeof opts.template === "string") {
    let testName = QUnit.config.currentModule.name + " " + name;
    // eslint-disable-next-line
    console.warn(
      `${testName} skipped; template must be compiled and not a string`
    );
    return;
  }

  test(name, async function (assert) {
    this.site = Site.current();
    this.session = Session.current();
    this.container = this.owner;
    const store = this.owner.lookup("service:store");

    autoLoadModules(this.owner, this.registry);

    if (!opts.anonymous) {
      const currentUser = User.create({
        username: "eviltrout",
        timezone: "Australia/Brisbane",
      });
      this.currentUser = currentUser;

      this.owner.unregister("current-user:main");
      this.owner.register("current-user:main", currentUser, {
        instantiate: false,
      });

      this.owner.inject("component", "currentUser", "current-user:main");
      this.owner.inject("service", "currentUser", "current-user:main");

      this.owner.unregister("topic-tracking-state:main");
      this.owner.register(
        "topic-tracking-state:main",
        TopicTrackingState.create({ currentUser }),
        { instantiate: false }
      );

      this.owner.inject(
        "service",
        "topicTrackingState",
        "topic-tracking-state:main"
      );
    }

    if (opts.beforeEach) {
      await opts.beforeEach.call(this, store);
    }

    $.fn.autocomplete = function () {};

    try {
      await render(opts.template);
      await opts.test.call(this, assert);
    } finally {
      if (opts.afterEach) {
        await opts.afterEach.call(opts);
      }
    }
  });
}
