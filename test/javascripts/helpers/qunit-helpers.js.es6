/* global asyncTest */

import siteFixtures from 'fixtures/site_fixtures';

function integration(name, options) {
  module("Integration: " + name, {
    setup: function() {
      Ember.run(Discourse, Discourse.advanceReadiness);

      var siteJson = siteFixtures['site.json'].site;
      if (options) {
        if (options.setup) {
          options.setup.call(this);
        }

        if (options.user) {
          Discourse.User.resetCurrent(Discourse.User.create(options.user));
        }

        if (options.settings) {
          Discourse.SiteSettings = jQuery.extend(true, Discourse.SiteSettings, options.settings);
        }

        if (options.site) {
          Discourse.Site.resetCurrent(Discourse.Site.create(jQuery.extend(true, {}, siteJson, options.site)));
        }
      }

      Discourse.reset();
    },

    teardown: function() {
      if (options && options.teardown) {
        options.teardown.call(this);
      }

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

export { integration, controllerFor, asyncTestDiscourse, fixture };
