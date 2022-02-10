import QUnit, { module, skip, test } from "qunit";
import { deepMerge } from "discourse-common/lib/object";
import MessageBus from "message-bus-client";
import {
  clearCache as clearOutletCache,
  resetExtraClasses,
} from "discourse/lib/plugin-connectors";
import { clearRewrites } from "discourse/lib/url";
import {
  currentSettings,
  mergeSettings,
} from "discourse/tests/helpers/site-settings";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { getApplication, getContext, settled } from "@ember/test-helpers";
import { getOwner } from "discourse-common/lib/get-owner";
import { run } from "@ember/runloop";
import { setupApplicationTest } from "ember-qunit";
import { Promise } from "rsvp";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import { clearHTMLCache } from "discourse/helpers/custom-html";
import deprecated from "discourse-common/lib/deprecated";
import { restoreBaseUri } from "discourse-common/lib/get-url";
import { flushMap } from "discourse/services/store";
import { initSearchData } from "discourse/widgets/search-menu";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { isEmpty } from "@ember/utils";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";
import { resetDecorators } from "discourse/widgets/widget";
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import { resetDecorators as resetPluginOutletDecorators } from "discourse/components/plugin-connector";
import { resetDecorators as resetPostCookedDecorators } from "discourse/widgets/post-cooked";
import { resetTopicTitleDecorators } from "discourse/components/topic-title";
import { resetUsernameDecorators } from "discourse/helpers/decorate-username-selector";
import { resetWidgetCleanCallbacks } from "discourse/components/mount-widget";
import { resetUserSearchCache } from "discourse/lib/user-search";
import { resetCardClickListenerSelector } from "discourse/mixins/card-contents-base";
import { resetComposerCustomizations } from "discourse/models/composer";
import { resetQuickSearchRandomTips } from "discourse/widgets/search-menu-results";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import {
  resetHighestReadCache,
  setTopicList,
} from "discourse/lib/topic-list-tracker";
import sinon from "sinon";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import { clearResolverOptions } from "discourse-common/resolver";
import { clearNavItems } from "discourse/models/nav-item";
import {
  cleanUpComposerUploadHandler,
  cleanUpComposerUploadMarkdownResolver,
  cleanUpComposerUploadPreProcessor,
} from "discourse/components/composer-editor";
import { resetLastEditNotificationClick } from "discourse/models/post-stream";
import { clearAuthMethods } from "discourse/models/login-method";
import { clearTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import { clearTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { clearDesktopNotificationHandlers } from "discourse/lib/desktop-notifications";
import {
  clearPresenceCallbacks,
  setTestPresence,
} from "discourse/lib/user-presence";
import PreloadStore from "discourse/lib/preload-store";

const LEGACY_ENV = !setupApplicationTest;

export function currentUser() {
  return User.create(sessionFixtures["/session/current.json"].current_user);
}

let _initialized = new Set();

export function testsInitialized() {
  _initialized.add(QUnit.config.current.testId);
}

export function testsTornDown() {
  _initialized.delete(QUnit.config.current.testId);
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
  let siteAttrs = Object.assign(
    {},
    siteFixtures["site.json"].site,
    extras || {}
  );
  siteAttrs.siteSettings = siteSettings;
  PreloadStore.store("site", siteAttrs);
  Site.resetCurrent();
}

export function applyPretender(name, server, helper) {
  const cb = _pretenderCallbacks[name];
  if (cb) {
    cb(server, helper);
  }
}

// Add clean up code here to run after every test
function testCleanup(container, app) {
  if (_initialized.has(QUnit.config.current.testId)) {
    if (!app) {
      app = getApplication();
    }
    app._runInitializer("instanceInitializers", (_, initializer) => {
      initializer.teardown?.();
    });

    app._runInitializer("initializers", (_, initializer) => {
      initializer.teardown?.(container);
    });
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
  resetUserSearchCache();
  resetHighestReadCache();
  resetCardClickListenerSelector();
  resetComposerCustomizations();
  resetQuickSearchRandomTips();
  resetPostMenuExtraButtons();
  clearNavItems();
  setTopicList(null);
  _clearSnapshots();
  cleanUpComposerUploadHandler();
  cleanUpComposerUploadMarkdownResolver();
  cleanUpComposerUploadPreProcessor();
  clearTopicFooterDropdowns();
  clearTopicFooterButtons();
  clearDesktopNotificationHandlers();
  resetLastEditNotificationClick();
  clearAuthMethods();
  setTestPresence(true);
  if (!LEGACY_ENV) {
    clearPresenceCallbacks();
  }
  restoreBaseUri();
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
      hooks.afterEach(() => testCleanup(this.container));

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
      options?.beforeEach?.call(this);
    },
    afterEach() {
      options?.afterEach?.call(this);
      testCleanup(this.container);
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
      { since: "2.6.0", dropFrom: "2.9.0.beta1" }
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

      if (!this.owner) {
        this.owner = this.container;
      }

      if (options.beforeEach) {
        options.beforeEach.call(this);
      }
    },

    afterEach() {
      resetMobile();
      let app = getApplication();
      options?.afterEach?.call(this);
      testCleanup(this.container, app);

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
    return document.querySelector(`#qunit-fixture ${selector}`);
  }
  return document.querySelector("#qunit-fixture");
}

QUnit.assert.not = function (actual, message) {
  deprecated("assert.not() is deprecated. Use assert.notOk() instead.", {
    since: "2.9.0.beta1",
    dropFrom: "2.10.0.beta1",
  });

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
    .forEach((c) => c.func(...args));
}

export async function selectText(selector, endOffset = null) {
  const range = document.createRange();
  let node;

  if (typeof selector === "string") {
    node = document.querySelector(selector);
  } else {
    node = selector;
  }

  range.selectNodeContents(node);

  if (endOffset) {
    range.setEnd(node, endOffset);
  }

  const performSelection = () => {
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
  };

  if (LEGACY_ENV) {
    // In the Ember CLI environment, the settled() helper seems to take care of waiting
    // for this event to fire. In legacy, we need to do it manually.
    let callback;
    const selectEventFiredPromise = new Promise((resolve) => {
      callback = resolve;
      document.addEventListener("selectionchange", callback);
    });

    performSelection();

    try {
      await selectEventFiredPromise;
    } finally {
      document.removeEventListener("selectionchange", callback);
    }
  } else {
    performSelection();
  }

  await settled();
}

export function conditionalTest(name, condition, testCase) {
  if (condition) {
    test(name, testCase);
  } else {
    skip(name, testCase);
  }
}

export function chromeTest(name, testCase) {
  conditionalTest(name, navigator.userAgent.includes("Chrome"), testCase);
}

export function firefoxTest(name, testCase) {
  conditionalTest(name, navigator.userAgent.includes("Firefox"), testCase);
}

export function createFile(name, type = "image/png", blobData = null) {
  // the blob content doesn't matter at all, just want it to be random-ish
  blobData = blobData || (Math.random() + 1).toString(36).substring(2);
  const blob = new Blob([blobData]);
  const file = new File([blob], name, {
    type,
    lastModified: new Date().getTime(),
  });
  return file;
}

export async function paste(element, text, otherClipboardData = {}) {
  let e = new Event("paste", { cancelable: true });
  e.clipboardData = deepMerge({ getData: () => text }, otherClipboardData);
  element.dispatchEvent(e);
  await settled();
  return e;
}
