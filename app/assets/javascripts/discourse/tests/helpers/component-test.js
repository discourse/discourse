import { render } from "@ember/test-helpers";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { autoLoadModules } from "discourse/instance-initializers/auto-load-modules";
import QUnit, { test } from "qunit";
import { setupRenderingTest as emberSetupRenderingTest } from "ember-qunit";
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
      groups: [
        {
          id: 10,
          automatic: true,
          name: "trust_level_0",
          display_name: "trust_level_0",
        },
        {
          id: 11,
          automatic: true,
          name: "trust_level_1",
          display_name: "trust_level_1",
        },
      ],
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

    $.fn.autocomplete = function () {};
  });
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
      this.owner.unregister("service:current-user");
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
