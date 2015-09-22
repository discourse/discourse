import DiscourseResolver from 'discourse/ember/resolver';

var originalTemplates, originalMobileViewFlag;
var resolver = DiscourseResolver.create();

function lookupTemplate(name, expectedTemplate, message) {
  var parseName = resolver.parseName(name);
  var result = resolver.resolveTemplate(parseName);
  equal(result, expectedTemplate, message);
}

function setTemplates(lookupTemplateStrings) {
  lookupTemplateStrings.forEach(function(lookupTemplateString) {
    Ember.TEMPLATES[lookupTemplateString] = lookupTemplateString;
  });
}

module("lib:resolver", {
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

  lookupTemplate("template:foobar", "foobar", "by lowcased name");
  lookupTemplate("template:fooBar", "fooBar", "by camel cased name");
  lookupTemplate("template:foo_bar", "foo_bar", "by underscored name");
  lookupTemplate("template:foo.bar", "foo.bar", "by dotted name");
});

test("finds templates in first-level subdir", function() {
  setTemplates([
    "foo/bar_baz"
  ]);

  lookupTemplate("template:foo/bar_baz", "foo/bar_baz", "with subdir defined by slash");
  lookupTemplate("template:foo.bar_baz", "foo/bar_baz", "with subdir defined by dot");
  lookupTemplate("template:fooBarBaz", "foo/bar_baz", "with subdir defined by first camel case and the rest of camel cases converted to underscores");
  lookupTemplate("template:foo_bar_baz", "foo/bar_baz", "with subdir defined by first underscore");
});

test("resolves precedence between overlapping top level dir and first level subdir templates", function() {
  setTemplates([
    "fooBar",
    "foo_bar",
    "foo.bar",
    "foo/bar"
  ]);

  lookupTemplate("template:foo.bar", "foo/bar", "preferring first level subdir for dotted name");
  lookupTemplate("template:fooBar", "fooBar", "preferring top level dir for camel cased name");
  lookupTemplate("template:foo_bar", "foo_bar", "preferring top level dir for underscored name");
});

test("finds templates in subdir deeper than one level", function() {
  setTemplates([
    "foo/bar/baz/qux"
  ]);

  lookupTemplate("template:foo/bar/baz/qux", "foo/bar/baz/qux", "for subdirs defined by slashes");
  lookupTemplate("template:foo.bar.baz.qux", "foo/bar/baz/qux", "for subdirs defined by dots");
  lookupTemplate("template:foo/bar/bazQux", "foo/bar/baz/qux", "for subdirs defined by slashes plus one camel case");
  lookupTemplate("template:foo/bar/baz_qux", "foo/bar/baz/qux", "for subdirs defined by slashes plus one underscore");

  lookupTemplate("template:fooBarBazQux", undefined, "but not for subdirs defined by more than one camel case");
  lookupTemplate("template:foo_bar_baz_qux", undefined, "but not for subdirs defined by more than one underscore");
  lookupTemplate("template:foo.bar.bazQux", undefined, "but not for subdirs defined by dots plus one camel case");
  lookupTemplate("template:foo.bar.baz_qux", undefined, "but not for subdirs defined by dots plus one underscore");
});

test("resolves mobile templates to 'mobile/' namespace", function() {
  setTemplates([
    "mobile/foo",
    "bar",
    "mobile/bar",
    "baz"
  ]);

  Discourse.Mobile.mobileView = true;

  lookupTemplate("template:foo", "mobile/foo", "finding mobile version even if normal one is not present");
  lookupTemplate("template:bar", "mobile/bar", "preferring mobile version when both mobile and normal versions are present");
  lookupTemplate("template:baz", "baz", "falling back to a normal version when mobile version is not present");
});

test("resolves plugin templates to 'javascripts/' namespace", function() {
  setTemplates([
    "javascripts/foo",
    "bar",
    "javascripts/bar",
    "baz"
  ]);

  lookupTemplate("template:foo", "javascripts/foo", "finding plugin version even if normal one is not present");
  lookupTemplate("template:bar", "javascripts/bar", "preferring plugin version when both versions are present");
  lookupTemplate("template:baz", "baz", "falling back to a normal version when plugin version is not present");
});

test("resolves templates with 'admin' prefix to 'admin/templates/' namespace", function() {
  setTemplates([
    "admin/templates/foo",
    "adminBar",
    "admin_bar",
    "admin.bar",
    "admin/templates/bar"
  ]);

  lookupTemplate("template:adminFoo", "admin/templates/foo", "when prefix is separated by camel case");
  lookupTemplate("template:admin_foo", "admin/templates/foo", "when prefix is separated by underscore");
  lookupTemplate("template:admin.foo", "admin/templates/foo", "when prefix is separated by dot");

  lookupTemplate("template:adminfoo", undefined, "but not when prefix is not separated in any way");
  lookupTemplate("template:adminBar", "adminBar", "but not when template with the exact camel cased name exists");
  lookupTemplate("template:admin_bar", "admin_bar", "but not when template with the exact underscored name exists");
  lookupTemplate("template:admin.bar", "admin.bar", "but not when template with the exact dotted name exists");
});

test("returns 'not_found' template when template name cannot be resolved", function() {
  setTemplates([
    "not_found"
  ]);

  lookupTemplate("template:foo/bar/baz", "not_found", "");
});
