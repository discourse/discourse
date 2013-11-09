var originalTemplates, originalMobileViewFlag;

var lookup = function(lookupString, expectedTemplate, message) {
  // {singleton: false} prevents Ember from caching lookup results (what would make them persistent across multiple tests, breaking test isolation)
  equal(Discourse.__container__.lookup(lookupString, {singleton: false}), expectedTemplate, message);
};

var setTemplates = function(lookupStrings) {  
  lookupStrings.forEach(function(lookupString) {
    Ember.TEMPLATES[lookupString] = lookupString;
  });
};

module("Discourse.Resolver", {
  setup: function() {
    originalTemplates = Ember.TEMPLATES;
    Ember.TEMPLATES = {};

    originalMobileViewFlag = Discourse.Mobile.mobileView;
    Discourse.Mobile.mobileView = false;
  },

  teardown: function() {
    Ember.TEMPLATES = originalTemplates;
    Discourse.Mobile.mobileView = originalMobileViewFlag;
  }
});

test("finds templates in top level dir", function() {
  setTemplates([
    "foobar",
    "fooBar",
    "foo_bar",
    "foo.bar"
  ]);

  lookup("template:foobar", "foobar", "by lowcased name");
  lookup("template:fooBar", "fooBar", "by camel cased name");
  lookup("template:foo_bar", "foo_bar", "by underscored name");
  lookup("template:foo.bar", "foo.bar", "by dotted name");
});

test("finds templates in first-level subdir", function() {
  setTemplates([
    "foo/bar_baz"
  ]);

  lookup("template:foo/bar_baz", "foo/bar_baz", "with subdir defined by slash");
  lookup("template:foo.bar_baz", "foo/bar_baz", "with subdir defined by dot");
  lookup("template:fooBarBaz", "foo/bar_baz", "with subdir defined by first camel case and the rest of camel cases converted to underscores");
  lookup("template:foo_bar_baz", "foo/bar_baz", "with subdir defined by first underscore");
});

test("resolves precedence between overlapping top level dir and first level subdir templates", function() {
  setTemplates([
    "fooBar",
    "foo_bar",
    "foo.bar",
    "foo/bar"
  ]);

  lookup("template:foo.bar", "foo/bar", "preferring first level subdir for dotted name");
  lookup("template:fooBar", "fooBar", "preferring top level dir for camel cased name");
  lookup("template:foo_bar", "foo_bar", "preferring top level dir for underscored name");
});

test("finds templates in subdir deeper than one level", function() {
  setTemplates([
    "foo/bar/baz/qux"
  ]);

  lookup("template:foo/bar/baz/qux", "foo/bar/baz/qux", "for subdirs defined by slashes");
  lookup("template:foo.bar.baz.qux", "foo/bar/baz/qux", "for subdirs defined by dots");
  lookup("template:foo/bar/bazQux", "foo/bar/baz/qux", "for subdirs defined by slashes plus one camel case");
  lookup("template:foo/bar/baz_qux", "foo/bar/baz/qux", "for subdirs defined by slashes plus one underscore");

  lookup("template:fooBarBazQux", undefined, "but not for subdirs defined by more than one camel case");
  lookup("template:foo_bar_baz_qux", undefined, "but not for subdirs defined by more than one underscore");
  lookup("template:foo.bar.bazQux", undefined, "but not for subdirs defined by dots plus one camel case");
  lookup("template:foo.bar.baz_qux", undefined, "but not for subdirs defined by dots plus one underscore");
});

test("resolves mobile templates to 'mobile/' namespace", function() {
  setTemplates([
    "mobile/foo",
    "bar",
    "mobile/bar",
    "baz"
  ]);

  Discourse.Mobile.mobileView = true;

  lookup("template:foo", "mobile/foo", "finding mobile version even if normal one is not present");
  lookup("template:bar", "mobile/bar", "preferring mobile version when both mobile and normal versions are present");
  lookup("template:baz", "baz", "falling back to a normal version when mobile version is not present");
});

test("resolves templates with 'admin' prefix to 'admin/templates/' namespace", function() {
  setTemplates([
    "admin/templates/foo",
    "adminBar",
    "admin_bar",
    "admin.bar",
    "admin/templates/bar"
  ]);

  lookup("template:adminFoo", "admin/templates/foo", "when prefix is separated by camel case");
  lookup("template:admin_foo", "admin/templates/foo", "when prefix is separated by underscore");
  lookup("template:admin.foo", "admin/templates/foo", "when prefix is separated by dot");

  lookup("template:adminfoo", undefined, "but not when prefix is not separated in any way");
  lookup("template:adminBar", "adminBar", "but not when template with the exact camel cased name exists");
  lookup("template:admin_bar", "admin_bar", "but not when template with the exact underscored name exists");
  lookup("template:admin.bar", "admin.bar", "but not when template with the exact dotted name exists");
});

test("returns 'not_found' template when template name cannot be resolved", function() {
  setTemplates([
    "not_found"
  ]);

  lookup("template:foo/bar/baz", "not_found", "");
});
