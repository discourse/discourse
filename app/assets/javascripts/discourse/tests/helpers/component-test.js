/* global andThen */

import { TestModuleForComponent, render } from "@ember/test-helpers";
import MessageBus from "message-bus-client";
import EmberObject from "@ember/object";
import { setupRenderingTest as EmberSetupRenderingTest } from "ember-qunit";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import { autoLoadModules } from "discourse/initializers/auto-load-modules";
import createStore from "discourse/tests/helpers/create-store";
import { currentSettings } from "discourse/tests/helpers/site-settings";
import QUnit, { test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";

const LEGACY_ENV = !EmberSetupRenderingTest;

export function setupRenderingTest(hooks) {
  if (!LEGACY_ENV) {
    return EmberSetupRenderingTest.apply(this, arguments);
  }

  let testModule;

  hooks.before(function () {
    const name = this.moduleName.split("|").pop();
    testModule = new TestModuleForComponent(name, {
      integration: true,
    });
  });

  hooks.beforeEach(function () {
    testModule.setContext(this);
    return testModule.setup(...arguments);
  });

  hooks.afterEach(function () {
    return testModule.teardown(...arguments);
  });

  hooks.after(function () {
    testModule = null;
  });
}

export default function (name, opts) {
  opts = opts || {};

  if (opts.skip) {
    return;
  }

  if (typeof opts.template === "string" && !LEGACY_ENV) {
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

    let owner = LEGACY_ENV ? this.registry : this.owner;
    let store;

    if (LEGACY_ENV) {
      this.registry.register("site-settings:main", currentSettings(), {
        instantiate: false,
      });
      this.registry.register("capabilities:main", EmberObject);
      this.registry.register("message-bus:main", MessageBus, {
        instantiate: false,
      });
      this.registry.register("site:main", this.site, { instantiate: false });
      this.registry.register("session:main", this.session, {
        instantiate: false,
      });
      const keyValueStore = new KeyValueStore("discourse_");
      this.registry.register("key-value-store:main", keyValueStore, {
        instantiate: false,
      });

      this.registry.injection(
        "component",
        "siteSettings",
        "site-settings:main"
      );
      this.registry.injection("component", "appEvents", "service:app-events");
      this.registry.injection("component", "capabilities", "capabilities:main");
      this.registry.injection("component", "site", "site:main");
      this.registry.injection("component", "session", "session:main");
      this.registry.injection("component", "messageBus", "message-bus:main");
      this.registry.injection(
        "component",
        "keyValueStore",
        "key-value-store:main"
      );

      this.registry.injection("service", "session", "session:main");
      this.registry.injection("service", "messageBus", "message-bus:main");
      this.registry.injection("service", "siteSettings", "site-settings:main");
      this.registry.injection(
        "service",
        "keyValueStore",
        "key-value-store:main"
      );

      this.siteSettings = currentSettings();
      store = createStore();
      this.registry.register("service:store", store, { instantiate: false });
    } else {
      this.container = owner;
      store = this.container.lookup("service:store");
    }

    autoLoadModules(this.container, this.registry);

    if (!opts.anonymous) {
      const currentUser = User.create({
        username: "eviltrout",
        timezone: "Australia/Brisbane",
      });
      this.currentUser = currentUser;

      owner.unregister("current-user:main");
      owner.register("current-user:main", currentUser, {
        instantiate: false,
      });

      if (LEGACY_ENV) {
        owner.injection("component", "currentUser", "current-user:main");
        owner.injection("service", "currentUser", "current-user:main");
      } else {
        owner.inject("component", "currentUser", "current-user:main");
        owner.inject("service", "currentUser", "current-user:main");
      }

      owner.unregister("topic-tracking-state:main");
      owner.register(
        "topic-tracking-state:main",
        TopicTrackingState.create({ currentUser }),
        { instantiate: false }
      );

      if (LEGACY_ENV) {
        owner.injection(
          "service",
          "topicTrackingState",
          "topic-tracking-state:main"
        );
      } else {
        owner.inject(
          "service",
          "topicTrackingState",
          "topic-tracking-state:main"
        );
      }
    }

    if (opts.beforeEach) {
      opts.beforeEach.call(this, store);
    }

    $.fn.autocomplete = function () {};
    andThen(() => {
      return LEGACY_ENV ? this.render(opts.template) : render(opts.template);
    });

    andThen(() => {
      return opts.test.call(this, assert);
    }).finally(async () => {
      if (opts.afterEach) {
        await andThen(() => {
          return opts.afterEach.call(opts);
        });
      }
    });
  });
}
