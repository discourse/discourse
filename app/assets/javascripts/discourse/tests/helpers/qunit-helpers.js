import { run } from "@ember/runloop";
import {
  getApplication,
  settled,
  triggerKeyEvent,
  typeIn,
} from "@ember/test-helpers";
import { isEmpty } from "@ember/utils";
import { setupApplicationTest } from "ember-qunit";
import $ from "jquery";
import MessageBus from "message-bus-client";
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import QUnit, { module, skip, test } from "qunit";
import sinon from "sinon";
import { clearAboutPageActivities } from "discourse/components/about-page";
import { resetCardClickListenerSelector } from "discourse/components/card-contents-base";
import {
  cleanUpComposerUploadHandler,
  cleanUpComposerUploadMarkdownResolver,
  cleanUpComposerUploadPreProcessor,
} from "discourse/components/composer-editor";
import { clearToolbarCallbacks } from "discourse/components/d-editor";
import { clearExtraHeaderButtons as clearExtraGlimmerHeaderButtons } from "discourse/components/header";
import { clearExtraHeaderIcons as clearExtraGlimmerHeaderIcons } from "discourse/components/header/icons";
import { resetWidgetCleanCallbacks } from "discourse/components/mount-widget";
import { resetDecorators as resetPluginOutletDecorators } from "discourse/components/plugin-connector";
import { resetItemSelectCallbacks } from "discourse/components/search-menu/results/assistant-item";
import { resetQuickSearchRandomTips } from "discourse/components/search-menu/results/random-quick-tip";
import { resetOnKeyUpCallbacks } from "discourse/components/search-menu/search-term";
import { resetTopicTitleDecorators } from "discourse/components/topic-title";
import { resetUserMenuProfileTabItems } from "discourse/components/user-menu/profile-tab-content";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";
import { clearHTMLCache } from "discourse/helpers/custom-html";
import { resetUsernameDecorators } from "discourse/helpers/decorate-username-selector";
import { resetBeforeAuthCompleteCallbacks } from "discourse/instance-initializers/auth-complete";
import { resetAdminPluginConfigNav } from "discourse/lib/admin-plugin-config-nav";
import { clearPluginHeaderActionComponents } from "discourse/lib/admin-plugin-header-actions";
import { rollbackAllPrepends } from "discourse/lib/class-prepend";
import { clearPopupMenuOptions } from "discourse/lib/composer/custom-popup-menu-options";
import { clearDesktopNotificationHandlers } from "discourse/lib/desktop-notifications";
import { cleanUpHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";
import {
  clearExtraKeyboardShortcutHelp,
  PLATFORM_KEY_MODIFIER,
} from "discourse/lib/keyboard-shortcuts";
import { reset as resetLinkLookup } from "discourse/lib/link-lookup";
import { resetMentions } from "discourse/lib/link-mentions";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { resetModelTransformers } from "discourse/lib/model-transformers";
import { resetNotificationTypeRenderers } from "discourse/lib/notification-types-manager";
import {
  clearCache as clearOutletCache,
  resetExtraClasses,
} from "discourse/lib/plugin-connectors";
import PreloadStore from "discourse/lib/preload-store";
import { clearTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { clearTopicFooterDropdowns } from "discourse/lib/register-topic-footer-dropdown";
import { clearTagsHtmlCallbacks } from "discourse/lib/render-tags";
import { resetLogSearchLinkClickedCallbacks } from "discourse/lib/search";
import { clearAdditionalAdminSidebarSectionLinks } from "discourse/lib/sidebar/admin-sidebar";
import { resetDefaultSectionLinks as resetTopicsSectionLinks } from "discourse/lib/sidebar/custom-community-section-links";
import { resetSidebarPanels } from "discourse/lib/sidebar/custom-sections";
import {
  clearBlockDecorateCallbacks,
  clearTagDecorateCallbacks,
  clearTextDecorateCallbacks,
} from "discourse/lib/to-markdown";
import {
  resetHighestReadCache,
  setTopicList,
} from "discourse/lib/topic-list-tracker";
import { resetTransformers } from "discourse/lib/transformer";
import { clearRewrites } from "discourse/lib/url";
import { resetUserMenuTabs } from "discourse/lib/user-menu/tab";
import {
  clearPresenceCallbacks,
  setTestPresence,
} from "discourse/lib/user-presence";
import { resetUserSearchCache } from "discourse/lib/user-search";
import { resetComposerCustomizations } from "discourse/models/composer";
import { clearAuthMethods } from "discourse/models/login-method";
import { clearNavItems } from "discourse/models/nav-item";
import { resetLastEditNotificationClick } from "discourse/models/post-stream";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import {
  currentSettings,
  mergeSettings,
} from "discourse/tests/helpers/site-settings";
import { resetDecorators as resetPostCookedDecorators } from "discourse/widgets/post-cooked";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { resetDecorators } from "discourse/widgets/widget";
import deprecated from "discourse-common/lib/deprecated";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { restoreBaseUri } from "discourse-common/lib/get-url";
import { cloneJSON, deepMerge } from "discourse-common/lib/object";
import { clearResolverOptions } from "discourse-common/resolver";
import I18n from "discourse-i18n";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import { setupFormKitAssertions } from "./form-kit-assertions";
import { cleanupTemporaryModuleRegistrations } from "./temporary-module-helper";

export function currentUser() {
  return User.create(
    cloneJSON(sessionFixtures["/session/current.json"].current_user)
  );
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
  return User.resetCurrent(currentUser());
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
    shouldClearNativeTimers: true,
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

export function resetSite(extras = {}) {
  const siteAttrs = {
    ...siteFixtures["site.json"].site,
    ...extras,
  };

  PreloadStore.store("site", cloneJSON(siteAttrs));
  Site.resetCurrent();
}

export function applyPretender(name, server, helper) {
  const cb = _pretenderCallbacks[name];
  if (cb) {
    cb(server, helper);
  }
}

// Add clean up code here to run after every test
export function testCleanup(container, app) {
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

  User.resetCurrent();
  resetMobile();
  resetExtraClasses();
  clearOutletCache();
  clearHTMLCache();
  clearRewrites();
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
  resetUserMenuProfileTabItems();
  clearExtraKeyboardShortcutHelp();
  clearNavItems();
  setTopicList(null);
  _clearSnapshots();
  cleanUpComposerUploadHandler();
  cleanUpComposerUploadMarkdownResolver();
  cleanUpComposerUploadPreProcessor();
  clearTopicFooterDropdowns();
  clearTopicFooterButtons();
  clearDesktopNotificationHandlers();
  cleanUpHashtagTypeClasses();
  resetLastEditNotificationClick();
  clearAuthMethods();
  setTestPresence(true);
  clearPresenceCallbacks();
  restoreBaseUri();
  resetTopicsSectionLinks();
  clearTagDecorateCallbacks();
  clearBlockDecorateCallbacks();
  clearTextDecorateCallbacks();
  clearResolverOptions();
  clearTagsHtmlCallbacks();
  clearToolbarCallbacks();
  resetNotificationTypeRenderers();
  resetSidebarPanels();
  clearExtraGlimmerHeaderIcons();
  clearExtraGlimmerHeaderButtons();
  resetOnKeyUpCallbacks();
  resetLogSearchLinkClickedCallbacks();
  resetItemSelectCallbacks();
  resetUserMenuTabs();
  resetLinkLookup();
  resetModelTransformers();
  resetMentions();
  cleanupTemporaryModuleRegistrations();
  cleanupCssGeneratorTags();
  resetBeforeAuthCompleteCallbacks();
  clearPopupMenuOptions();
  clearAdditionalAdminSidebarSectionLinks();
  resetAdminPluginConfigNav();
  resetTransformers();
  rollbackAllPrepends();
  clearAboutPageActivities();
  resetWidgetCleanCallbacks();
  clearPluginHeaderActionComponents();
}

function cleanupCssGeneratorTags() {
  document.querySelector("style#category-color-css-generator")?.remove();
  document.querySelector("style#category-badge-css-generator")?.remove();
  document.querySelector("style#hashtag-css-generator")?.remove();
}

export function discourseModule(name, options) {
  // deprecated(
  //   `${name}: \`discourseModule\` is deprecated. Use QUnit's \`module\` instead.`,
  //   { since: "2.6.0" }
  // );

  if (typeof options === "function") {
    module(name, function (hooks) {
      hooks.beforeEach(function () {
        this.container = getOwnerWithFallback(this);
        this.registry = this.container.registry;
        this.owner = this.container;
        this.siteSettings = currentSettings();
      });

      this.getController = function (controllerName, properties) {
        let controller = this.container.lookup(`controller:${controllerName}`);
        controller.application = {};
        controller.siteSettings = this.siteSettings;
        if (properties) {
          controller.setProperties(properties);
        }
        return controller;
      };

      this.moduleName = name;

      hooks.usingDiscourseModule = true;
      options.call(this, hooks);
    });

    return;
  }

  module(name, {
    beforeEach() {
      this.container = getOwnerWithFallback(this);
      this.siteSettings = currentSettings();
      options?.beforeEach?.call(this);
    },
    afterEach() {
      options?.afterEach?.call(this);
    },
  });
}

export function addPretenderCallback(name, fn) {
  if (name && fn) {
    if (_pretenderCallbacks[name]) {
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
      {
        since: "2.6.0",
        dropFrom: "2.9.0.beta1",
        id: "discourse.qunit.acceptance-function",
      }
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
      I18n.testing = true;

      resetExtraClasses();
      if (mobileView) {
        forceMobile();
      }

      if (loggedIn) {
        logIn();
        if (userChanges) {
          updateCurrentUser(userChanges);
        }

        User.current().statusManager.trackStatus();
      }

      if (settingChanges) {
        mergeSettings(settingChanges);
      }

      this.siteSettings = currentSettings();

      resetSite(siteChanges);

      this.container = getOwnerWithFallback(this);

      if (!this.owner) {
        this.owner = this.container;
      }

      if (options.beforeEach) {
        options.beforeEach.call(this);
      }
    },

    afterEach() {
      I18n.testing = false;
      options?.afterEach?.call(this);
      if (loggedIn) {
        User.current().statusManager.stopTrackingStatus();
      }
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

      setupApplicationTest(hooks);
    });
  } else {
    // Old way
    module(name, setup);
  }
}

export function fixture(selector) {
  if (selector) {
    return document.querySelector(`#qunit-fixture ${selector}`);
  }
  return document.querySelector("#qunit-fixture");
}

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

setupFormKitAssertions();

export async function selectDate(selector, date) {
  const elem = document.querySelector(selector);
  elem.value = date;
  const evt = new Event("input", { bubbles: true, cancelable: false });
  elem.dispatchEvent(evt);
  elem.blur();
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

export async function publishToMessageBus(channelPath, ...args) {
  args = cloneJSON(args);

  const promises = MessageBus.callbacks
    .filterBy("channel", channelPath)
    .map((callback) => callback.func(...args));

  await Promise.allSettled(promises);
  await settled();
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

  performSelection();

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

export async function simulateKey(element, key) {
  if (key === "\b") {
    await triggerKeyEvent(element, "keydown", "Backspace");

    const pos = element.selectionStart;
    element.value = element.value.slice(0, pos - 1) + element.value.slice(pos);
    element.selectionStart = pos - 1;
    element.selectionEnd = pos - 1;

    await triggerKeyEvent(element, "keyup", "Backspace");
  } else if (key === "\t") {
    await triggerKeyEvent(element, "keydown", "Tab");
    await triggerKeyEvent(element, "keyup", "Tab");
  } else if (key === "\r") {
    await triggerKeyEvent(element, "keydown", "Enter");
    await triggerKeyEvent(element, "keyup", "Enter");
  } else {
    await typeIn(element, key);
  }
}

export async function simulateKeys(element, keys) {
  for (let key of keys) {
    await simulateKey(element, key);
  }
}

// The order of attributes can vary in different browsers. When comparing
// HTML strings from the DOM, this function helps to normalize them to make
// comparison work cross-browser
export function normalizeHtml(html) {
  const resultElement = document.createElement("template");
  resultElement.innerHTML = html;
  return resultElement.innerHTML;
}

export const metaModifier = { [`${PLATFORM_KEY_MODIFIER}Key`]: true };
