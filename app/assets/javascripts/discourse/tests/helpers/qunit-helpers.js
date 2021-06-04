import QUnit, { module } from "qunit";
import MessageBus from "message-bus-client";
import {
  clearCache as clearOutletCache,
  resetExtraClasses,
} from "discourse/lib/plugin-connectors";
import { clearRewrites, setURLContainer } from "discourse/lib/url";
import {
  currentSettings,
  mergeSettings,
} from "discourse/tests/helpers/site-settings";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { getApplication, getContext } from "@ember/test-helpers";
import { getOwner, setDefaultOwner } from "discourse-common/lib/get-owner";
import { later, run } from "@ember/runloop";
import { moduleFor, setupApplicationTest } from "ember-qunit";
import HeaderComponent from "discourse/components/site-header";
import { Promise } from "rsvp";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import { clearHTMLCache } from "discourse/helpers/custom-html";
import createStore from "discourse/tests/helpers/create-store";
import deprecated from "discourse-common/lib/deprecated";
import { flushMap } from "discourse/models/store";
import { initSearchData } from "discourse/widgets/search-menu";
import { isEmpty } from "@ember/utils";
import { mapRoutes } from "discourse/mapping-router";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";
import { resetDecorators } from "discourse/widgets/widget";
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import { resetDecorators as resetPluginOutletDecorators } from "discourse/components/plugin-connector";
import { resetDecorators as resetPostCookedDecorators } from "discourse/widgets/post-cooked";
import { resetTopicTitleDecorators } from "discourse/components/topic-title";
import { resetUsernameDecorators } from "discourse/helpers/decorate-username-selector";
import { resetWidgetCleanCallbacks } from "discourse/components/mount-widget";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import sinon from "sinon";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import { clearResolverOptions } from "discourse-common/resolver";
import { clearCustomNavItemHref } from "discourse/models/nav-item";
import {
  cleanUpComposerUploadHandler,
  cleanUpComposerUploadMarkdownResolver,
  cleanUpComposerUploadProcessor,
} from "discourse/components/composer-editor";

const LEGACY_ENV = !setupApplicationTest;

export function currentUser() {
  return User.create(sessionFixtures["/session/current.json"].current_user);
}

export function updateCurrentUser(properties) {
  run(() => {
    User.current().setProperties(properties);
  });
}

// Note: do not use this in acceptance tests. Use `loggedIn: true` instead
export function logIn() {
  User.resetCurrent(currentUser());
}

// Note: Only use if `loggedIn: true` has been used in an acceptance test
export function loggedInUser() {
  return User.current();
}

export function fakeTime(timeString, timezone = null, advanceTime = false) {
  let now = moment.tz(timeString, timezone);
  return sinon.useFakeTimers({
    now: now.valueOf(),
    shouldAdvanceTime: advanceTime,
  });
}

export function withFrozenTime(timeString, timezone, callback) {
  const clock = fakeTime(timeString, timezone, false);
  try {
    callback();
  } finally {
    clock.restore();
  }
}

let _pretenderCallbacks = {};

export function resetSite(siteSettings, extras) {
  let siteAttrs = $.extend({}, siteFixtures["site.json"].site, extras || {});
  siteAttrs.store = createStore();
  siteAttrs.siteSettings = siteSettings;
  return Site.resetCurrent(Site.create(siteAttrs));
}

export function applyPretender(name, server, helper) {
  const cb = _pretenderCallbacks[name];
  if (cb) {
    cb(server, helper);
  }
}

export function controllerModule(name, args = {}) {
  moduleFor(name, name, {
    setup() {
      this.registry.register("router:main", mapRoutes());
      let controller = this.subject();
      controller.siteSettings = currentSettings();
      if (args.setupController) {
        args.setupController(controller);
      }
    },
    needs: args.needs,
  });
}

export function discourseModule(name, options) {
  // deprecated(
  //   `${name}: \`discourseModule\` is deprecated. Use QUnit's \`module\` instead.`,
  //   { since: "2.6.0" }
  // );

  if (typeof options === "function") {
    module(name, function (hooks) {
      hooks.beforeEach(function () {
        this.container = getOwner(this);
        this.registry = this.container.registry;
        this.owner = this.container;
        this.siteSettings = currentSettings();
        clearResolverOptions();
      });

      this.getController = function (controllerName, properties) {
        let controller = this.container.lookup(`controller:${controllerName}`);
        if (!LEGACY_ENV) {
          controller.application = {};
        }
        controller.siteSettings = this.siteSettings;
        if (properties) {
          controller.setProperties(properties);
        }
        return controller;
      };

      this.moduleName = name;

      options.call(this, hooks);
    });

    return;
  }

  module(name, {
    beforeEach() {
      this.container = getOwner(this);
      this.siteSettings = currentSettings();
      if (options && options.beforeEach) {
        options.beforeEach.call(this);
      }
    },
    afterEach() {
      if (options && options.afterEach) {
        options.afterEach.call(this);
      }
    },
  });
}

export function addPretenderCallback(name, fn) {
  if (name && fn) {
    if (_pretenderCallbacks[name]) {
      // eslint-disable-next-line no-console
      throw `There is already a pretender callback with module name (${name}).`;
    }

    _pretenderCallbacks[name] = fn;
  }
}

export function acceptance(name, optionsOrCallback) {
  name = `Acceptance: ${name}`;

  let callback;
  let options = {};
  if (typeof optionsOrCallback === "function") {
    callback = optionsOrCallback;
  } else if (typeof optionsOrCallback === "object") {
    deprecated(
      `${name}: The second parameter to \`acceptance\` should be a function that encloses your tests.`,
      { since: "2.6.0" }
    );
    options = optionsOrCallback;
  }

  addPretenderCallback(name, options.pretend);

  let loggedIn = false;
  let mobileView = false;
  let siteChanges;
  let settingChanges;
  let userChanges;

  const setup = {
    beforeEach() {
      resetMobile();

      // For now don't do scrolling stuff in Test Mode
      HeaderComponent.reopen({ examineDockHeader: function () {} });

      resetExtraClasses();
      if (mobileView) {
        forceMobile();
      }

      if (loggedIn) {
        logIn();
        if (userChanges) {
          updateCurrentUser(userChanges);
        }
      }

      if (settingChanges) {
        mergeSettings(settingChanges);
      }
      this.siteSettings = currentSettings();

      clearOutletCache();
      clearHTMLCache();

      resetSite(currentSettings(), siteChanges);

      if (LEGACY_ENV) {
        getApplication().__registeredObjects__ = false;
        getApplication().reset();
      }
      this.container = getOwner(this);
      if (LEGACY_ENV && loggedIn) {
        updateCurrentUser({
          appEvents: this.container.lookup("service:app-events"),
        });
      }

      setURLContainer(this.container);
      setDefaultOwner(this.container);
      if (!this.owner) {
        this.owner = this.container;
      }

      if (options.beforeEach) {
        options.beforeEach.call(this);
      }
    },

    afterEach() {
      let app = getApplication();
      if (options && options.afterEach) {
        options.afterEach.call(this);
      }
      flushMap();
      localStorage.clear();
      User.resetCurrent();
      resetExtraClasses();
      clearOutletCache();
      clearHTMLCache();
      clearRewrites();
      initSearchData();
      resetDecorators();
      resetPostCookedDecorators();
      resetPluginOutletDecorators();
      resetTopicTitleDecorators();
      resetUsernameDecorators();
      resetOneboxCache();
      resetCustomPostMessageCallbacks();
      clearCustomNavItemHref();
      setTopicList(null);
      _clearSnapshots();
      setURLContainer(null);
      setDefaultOwner(null);
      cleanUpComposerUploadHandler();
      cleanUpComposerUploadProcessor();
      cleanUpComposerUploadMarkdownResolver();
      app._runInitializer("instanceInitializers", (initName, initializer) => {
        if (initializer && initializer.teardown) {
          initializer.teardown(this.container);
        }
      });

      if (LEGACY_ENV) {
        app.__registeredObjects__ = false;
        app.reset();
      }

      // We do this after reset so that the willClearRender will have already fired
      resetWidgetCleanCallbacks();
    },
  };

  const needs = {
    user(changes) {
      loggedIn = true;
      userChanges = changes;
    },
    pretender(fn) {
      addPretenderCallback(name, fn);
    },
    site(changes) {
      siteChanges = changes;
    },
    settings(changes) {
      settingChanges = changes;
    },
    mobileView() {
      mobileView = true;
    },
  };

  if (options.loggedIn) {
    needs.user();
  }
  if (options.site) {
    needs.site(options.site);
  }
  if (options.settings) {
    needs.settings(options.settings);
  }
  if (options.mobileView) {
    needs.mobileView();
  }

  if (callback) {
    // New, preferred way
    module(name, function (hooks) {
      needs.hooks = hooks;
      hooks.beforeEach(setup.beforeEach);
      hooks.afterEach(setup.afterEach);
      callback(needs);

      if (!LEGACY_ENV && getContext) {
        setupApplicationTest(hooks);

        hooks.beforeEach(function () {
          // This hack seems necessary to allow `DiscourseURL` to use the testing router
          let ctx = getContext();
          this.container.registry.unregister("router:main");
          this.container.registry.register("router:main", ctx.owner.router, {
            instantiate: false,
          });
        });
      }
    });
  } else {
    // Old way
    module(name, setup);
  }
}

export function controllerFor(controller, model) {
  controller = getOwner(this).lookup("controller:" + controller);
  if (model) {
    controller.set("model", model);
  }
  return controller;
}

export function fixture(selector) {
  if (selector) {
    return $("#qunit-fixture").find(selector);
  }
  return $("#qunit-fixture");
}

QUnit.assert.not = function (actual, message) {
  this.pushResult({
    result: !actual,
    actual,
    expected: !actual,
    message,
  });
};

QUnit.assert.blank = function (actual, message) {
  this.pushResult({
    result: isEmpty(actual),
    actual,
    message,
  });
};

QUnit.assert.present = function (actual, message) {
  this.pushResult({
    result: !isEmpty(actual),
    actual,
    message,
  });
};

QUnit.assert.containsInstance = function (collection, klass, message) {
  const result = klass.detectInstance(collection[0]);
  this.pushResult({
    result,
    message,
  });
};

export function waitFor(assert, callback, timeout) {
  timeout = timeout || 500;

  const done = assert.async();
  later(() => {
    callback();
    done();
  }, timeout);
}

export async function selectDate(selector, date) {
  return new Promise((resolve) => {
    const elem = document.querySelector(selector);
    elem.value = date;
    const evt = new Event("input", { bubbles: true, cancelable: false });
    elem.dispatchEvent(evt);
    elem.blur();

    resolve();
  });
}

export function queryAll(selector, context) {
  context = context || "#ember-testing";
  return $(selector, context);
}

export function query() {
  return document.querySelector("#ember-testing").querySelector(...arguments);
}

export function invisible(selector) {
  const $items = queryAll(selector + ":visible");
  return (
    $items.length === 0 ||
    $items.css("opacity") !== "1" ||
    $items.css("visibility") === "hidden"
  );
}

export function visible(selector) {
  return queryAll(selector + ":visible").length > 0;
}

export function count(selector) {
  return queryAll(selector).length;
}

export function exists(selector) {
  return count(selector) > 0;
}

export function publishToMessageBus(channelPath, ...args) {
  MessageBus.callbacks
    .filterBy("channel", channelPath)
    .map((c) => c.func(...args));
}
