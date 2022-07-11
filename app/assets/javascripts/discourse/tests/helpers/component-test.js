import { render } from "@ember/test-helpers";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { autoLoadModules } from "discourse/initializers/auto-load-modules";
import QUnit, { test } from "qunit";
import { setupRenderingTest as emberSetupRenderingTest } from "ember-qunit";
import { currentSettings } from "discourse/tests/helpers/site-settings";
import { clearResolverOptions } from "discourse-common/resolver";
import { testCleanup } from "discourse/tests/helpers/qunit-helpers";

export function setupRenderingTest(hooks) {
  emberSetupRenderingTest(hooks);

  hooks.beforeEach(function () {
    if (!hooks.usingDiscourseModule) {
      this.siteSettings = currentSettings();

      if (!this.registry) {
        this.registry = this.owner.__registry__;
      }

      this.container = this.owner;
      clearResolverOptions();
    }

    this.site = Site.current();
    this.session = Session.current();

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

    autoLoadModules(this.owner, this.registry);
    this.owner.lookup("service:store");

    $.fn.autocomplete = function () {};
  });

  if (!hooks.usingDiscourseModule) {
    hooks.afterEach(function () {
      testCleanup(this.container);
    });
  }
}

export default function (name, hooks, opts) {
  if (opts === undefined) {
    opts = hooks;
  }

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
    if (opts.anonymous) {
      this.owner.unregister("current-user:main");
    }

    if (opts.beforeEach) {
      const store = this.owner.lookup("service:store");
      await opts.beforeEach.call(this, store);
    }

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
