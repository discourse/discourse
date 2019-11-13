import { isEmpty } from "@ember/utils";
import { run } from "@ember/runloop";
import { later } from "@ember/runloop";
/* global QUnit, resetSite */

import sessionFixtures from "fixtures/session-fixtures";
import HeaderComponent from "discourse/components/site-header";
import { forceMobile, resetMobile } from "discourse/lib/mobile";
import { resetPluginApi } from "discourse/lib/plugin-api";
import {
  clearCache as clearOutletCache,
  resetExtraClasses
} from "discourse/lib/plugin-connectors";
import { clearHTMLCache } from "discourse/helpers/custom-html";
import { flushMap } from "discourse/models/store";
import { clearRewrites } from "discourse/lib/url";
import { initSearchData } from "discourse/widgets/search-menu";
import { resetDecorators } from "discourse/widgets/widget";
import { resetWidgetCleanCallbacks } from "discourse/components/mount-widget";
import { resetDecorators as resetPostCookedDecorators } from "discourse/widgets/post-cooked";
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";
import User from "discourse/models/user";

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

const Plugin = $.fn.modal;
const Modal = Plugin.Constructor;

function AcceptanceModal(option, _relatedTarget) {
  return this.each(function() {
    var $this = $(this);
    var data = $this.data("bs.modal");
    var options = $.extend(
      {},
      Modal.DEFAULTS,
      $this.data(),
      typeof option === "object" && option
    );

    if (!data) $this.data("bs.modal", (data = new Modal(this, options)));
    data.$body = $("#ember-testing");

    if (typeof option === "string") data[option](_relatedTarget);
    else if (options.show) data.show(_relatedTarget);
  });
}

window.bootbox.$body = $("#ember-testing");
$.fn.modal = AcceptanceModal;

let _pretenderCallbacks = {};

export function applyPretender(name, server, helper) {
  const cb = _pretenderCallbacks[name];
  if (cb) cb(server, helper);
}

export function acceptance(name, options) {
  options = options || {};

  if (options.pretend) {
    _pretenderCallbacks[name] = options.pretend;
  }

  QUnit.module("Acceptance: " + name, {
    beforeEach() {
      resetMobile();

      // For now don't do scrolling stuff in Test Mode
      HeaderComponent.reopen({ examineDockHeader: function() {} });

      resetExtraClasses();
      if (options.beforeEach) {
        options.beforeEach.call(this);
      }

      if (options.mobileView) {
        forceMobile();
      }

      if (options.loggedIn) {
        logIn();
      }

      if (options.settings) {
        Discourse.SiteSettings = jQuery.extend(
          true,
          Discourse.SiteSettings,
          options.settings
        );
      }

      if (options.site) {
        resetSite(Discourse.SiteSettings, options.site);
      }

      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      Discourse.reset();
    },

    afterEach() {
      if (options && options.afterEach) {
        options.afterEach.call(this);
      }
      flushMap();
      localStorage.clear();
      User.resetCurrent();
      resetSite(Discourse.SiteSettings);
      resetExtraClasses();
      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      clearRewrites();
      initSearchData();
      resetDecorators();
      resetPostCookedDecorators();
      resetOneboxCache();
      resetCustomPostMessageCallbacks();
      Discourse._runInitializer("instanceInitializers", function(
        initName,
        initializer
      ) {
        if (initializer && initializer.teardown) {
          initializer.teardown(Discourse.__container__);
        }
      });
      Discourse.reset();

      // We do this after reset so that the willClearRender will have already fired
      resetWidgetCleanCallbacks();
    }
  });
}

export function controllerFor(controller, model) {
  controller = Discourse.__container__.lookup("controller:" + controller);
  if (model) {
    controller.set("model", model);
  }
  return controller;
}

export function asyncTestDiscourse(text, func) {
  QUnit.test(text, function(assert) {
    const done = assert.async();
    run(() => {
      func.call(this, assert);
      done();
    });
  });
}

export function fixture(selector) {
  if (selector) {
    return $("#qunit-fixture").find(selector);
  }
  return $("#qunit-fixture");
}

QUnit.assert.not = function(actual, message) {
  this.pushResult({
    result: !actual,
    actual,
    expected: !actual,
    message
  });
};

QUnit.assert.blank = function(actual, message) {
  this.pushResult({
    result: isEmpty(actual),
    actual,
    message
  });
};

QUnit.assert.present = function(actual, message) {
  this.pushResult({
    result: !isEmpty(actual),
    actual,
    message
  });
};

QUnit.assert.containsInstance = function(collection, klass, message) {
  const result = klass.detectInstance(_.first(collection));
  this.pushResult({
    result,
    message
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
