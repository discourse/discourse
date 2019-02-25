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
import { resetCache as resetOneboxCache } from "pretty-text/oneboxer";
import { resetCustomPostMessageCallbacks } from "discourse/controllers/topic";

export function currentUser() {
  return Discourse.User.create(
    sessionFixtures["/session/current.json"].current_user
  );
}

export function replaceCurrentUser(properties) {
  const user = Discourse.User.current();
  user.setProperties(properties);
  Discourse.User.resetCurrent(user);
}

export function logIn() {
  Discourse.User.resetCurrent(currentUser());
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

let _pretenderCallbacks = [];

export function applyPretender(server, helper) {
  _pretenderCallbacks.forEach(cb => cb(server, helper));
}

export function acceptance(name, options) {
  options = options || {};

  if (options.pretend) {
    _pretenderCallbacks.push(options.pretend);
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
      Discourse.User.resetCurrent();
      resetSite(Discourse.SiteSettings);
      resetExtraClasses();
      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      clearRewrites();
      initSearchData();
      resetDecorators();
      resetOneboxCache();
      resetCustomPostMessageCallbacks();
      Discourse.reset();
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
    Ember.run(() => {
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
    result: Ember.isEmpty(actual),
    actual,
    message
  });
};

QUnit.assert.present = function(actual, message) {
  this.pushResult({
    result: !Ember.isEmpty(actual),
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
  Ember.run.later(() => {
    callback();
    done();
  }, timeout);
}
