import { Promise } from "rsvp";
import { isEmpty } from "@ember/utils";
import { later } from "@ember/runloop";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import HeaderComponent from "discourse/components/site-header";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { resetPluginApi } from "discourse/lib/plugin-api";
import {
  clearCache as clearOutletCache,
  resetExtraClasses,
} from "discourse/lib/plugin-connectors";
import { clearHTMLCache } from "discourse/helpers/custom-html";
import { flushMap } from "discourse/models/store";
import { clearRewrites } from "discourse/lib/url";
import { initSearchData } from "discourse/widgets/search-menu";
import { resetDecorators } from "discourse/widgets/widget";
import { resetWidgetCleanCallbacks } from "discourse/components/mount-widget";
import { resetTopicTitleDecorators } from "discourse/components/topic-title";
import { resetDecorators as resetPostCookedDecorators } from "discourse/widgets/post-cooked";
import { resetDecorators as resetPluginOutletDecorators } from "discourse/components/plugin-connector";
import { resetUsernameDecorators } from "discourse/helpers/decorate-username-selector";
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import User from "discourse/models/user";
import { mapRoutes } from "discourse/mapping-router";
import {
  currentSettings,
  mergeSettings,
} from "discourse/tests/helpers/site-settings";
import { getOwner } from "discourse-common/lib/get-owner";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { setURLContainer } from "discourse/lib/url";
import { setDefaultOwner } from "discourse-common/lib/get-owner";
import bootbox from "bootbox";
import { moduleFor } from "ember-qunit";
import QUnit, { module } from "qunit";
import siteFixtures from "discourse/tests/fixtures/site-fixtures";
import Site from "discourse/models/site";
import createStore from "discourse/tests/helpers/create-store";
import { getApplication } from "@ember/test-helpers";
import deprecated from "discourse-common/lib/deprecated";
import sinon from "sinon";

export function currentUser() {
  return User.create(sessionFixtures["/session/current.json"].current_user);
}

export function updateCurrentUser(properties) {
  User.current().setProperties(properties);
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

const Plugin = $.fn.modal;
const Modal = Plugin.Constructor;

function AcceptanceModal(option, _relatedTarget) {
  return this.each(function () {
    var $this = $(this);
    var data = $this.data("bs.modal");
    var options = $.extend(
      {},
      Modal.DEFAULTS,
      $this.data(),
      typeof option === "object" && option
    );

    if (!data) {
      $this.data("bs.modal", (data = new Modal(this, options)));
    }
    data.$body = $("#ember-testing");

    if (typeof option === "string") {
      data[option](_relatedTarget);
    } else if (options.show) {
      data.show(_relatedTarget);
    }
  });
}

bootbox.$body = $("#ember-testing");
$.fn.modal = AcceptanceModal;

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

export function discourseModule(name, hooks) {
  module(name, {
    beforeEach() {
      this.container = getOwner(this);
      this.siteSettings = currentSettings();
      if (hooks && hooks.beforeEach) {
        hooks.beforeEach.call(this);
      }
    },
    afterEach() {
      if (hooks && hooks.afterEach) {
        hooks.afterEach.call(this);
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
      resetPluginApi();

      if (siteChanges) {
        resetSite(currentSettings(), siteChanges);
      }

      getApplication().reset();
      this.container = getOwner(this);
      setURLContainer(this.container);
      setDefaultOwner(this.container);

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
      resetSite(currentSettings());
      resetExtraClasses();
      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      clearRewrites();
      initSearchData();
      resetDecorators();
      resetPostCookedDecorators();
      resetPluginOutletDecorators();
      resetTopicTitleDecorators();
      resetUsernameDecorators();
      resetOneboxCache();
      resetCustomPostMessageCallbacks();
      setTopicList(null);
      _clearSnapshots();
      setURLContainer(null);
      setDefaultOwner(null);
      app._runInitializer("instanceInitializers", (initName, initializer) => {
        if (initializer && initializer.teardown) {
          initializer.teardown(this.container);
        }
      });
      app.reset();

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
      hooks.beforeEach(setup.beforeEach);
      hooks.afterEach(setup.afterEach);
      needs.hooks = hooks;
      callback(needs);
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

export function invisible(selector) {
  const $items = find(selector + ":visible");
  return (
    $items.length === 0 ||
    $items.css("opacity") !== "1" ||
    $items.css("visibility") === "hidden"
  );
}

export function visible(selector) {
  return find(selector + ":visible").length > 0;
}

export function count(selector) {
  return find(selector).length;
}

export function exists(selector) {
  return count(selector) > 0;
}
