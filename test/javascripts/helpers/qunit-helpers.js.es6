/* global asyncTest, fixtures */

import sessionFixtures from 'fixtures/session-fixtures';
import siteFixtures from 'fixtures/site-fixtures';
import HeaderComponent from 'discourse/components/site-header';
import { forceMobile, resetMobile } from 'discourse/lib/mobile';
import { resetPluginApi } from 'discourse/lib/plugin-api';
import { clearCache as clearOutletCache, resetExtraClasses } from 'discourse/lib/plugin-connectors';
import { clearHTMLCache } from 'discourse/helpers/custom-html';
import { flushMap } from 'discourse/models/store';


function currentUser() {
  return Discourse.User.create(sessionFixtures['/session/current.json'].current_user);
}

function logIn() {
  Discourse.User.resetCurrent(currentUser());
}

const Plugin = $.fn.modal;
const Modal = Plugin.Constructor;

function AcceptanceModal(option, _relatedTarget) {
  return this.each(function () {
    var $this   = $(this);
    var data    = $this.data('bs.modal');
    var options = $.extend({}, Modal.DEFAULTS, $this.data(), typeof option === 'object' && option);

    if (!data) $this.data('bs.modal', (data = new Modal(this, options)));
    data.$body = $('#ember-testing');

    if (typeof option === 'string') data[option](_relatedTarget);
    else if (options.show) data.show(_relatedTarget);
  });
}

window.bootbox.$body = $('#ember-testing');
$.fn.modal = AcceptanceModal;

function acceptance(name, options) {
  module("Acceptance: " + name, {
    setup() {
      resetMobile();

      // For now don't do scrolling stuff in Test Mode
      HeaderComponent.reopen({examineDockHeader: Ember.K});

      resetExtraClasses();
      const siteJson = siteFixtures['site.json'].site;
      if (options) {
        if (options.setup) {
          options.setup.call(this);
        }

        if (options.mobileView) {
          forceMobile();
        }

        if (options.loggedIn) {
          logIn();
        }

        if (options.settings) {
          Discourse.SiteSettings = jQuery.extend(true, Discourse.SiteSettings, options.settings);
        }

        if (options.site) {
          Discourse.Site.resetCurrent(Discourse.Site.create(jQuery.extend(true, {}, siteJson, options.site)));
        }
      }

      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      Discourse.reset();
    },

    teardown() {
      if (options && options.teardown) {
        options.teardown.call(this);
      }
      flushMap();
      Discourse.User.resetCurrent();
      Discourse.Site.resetCurrent(Discourse.Site.create(jQuery.extend(true, {}, fixtures['site.json'].site)));

      resetExtraClasses();
      clearOutletCache();
      clearHTMLCache();
      resetPluginApi();
      Discourse.reset();
    }
  });
}

function controllerFor(controller, model) {
  controller = Discourse.__container__.lookup('controller:' + controller);
  if (model) { controller.set('model', model ); }
  return controller;
}

function asyncTestDiscourse(text, func) {
  asyncTest(text, function () {
    var self = this;
    Ember.run(function () {
      func.call(self);
    });
  });
}

function fixture(selector) {
  if (selector) {
    return $("#qunit-fixture").find(selector);
  }
  return $("#qunit-fixture");
}

function present(obj, text) {
  ok(!Ember.isEmpty(obj), text);
}

function blank(obj, text) {
  ok(Ember.isEmpty(obj), text);
}

function waitFor(callback, timeout) {
  timeout = timeout || 500;
  stop();
  Ember.run.later(() => {
    callback();
    start();
  }, timeout);
}

export { acceptance,
         controllerFor,
         asyncTestDiscourse,
         fixture,
         logIn,
         currentUser,
         blank,
         present,
         waitFor };
