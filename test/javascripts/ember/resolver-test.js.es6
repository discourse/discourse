import { setResolverOption, buildResolver } from "discourse-common/resolver";

let originalTemplates;
let resolver;

function lookupTemplate(assert, name, expectedTemplate, message) {
  var parseName = resolver.parseName(name);
  var result = resolver.resolveTemplate(parseName);
  assert.equal(result, expectedTemplate, message);
}

function setTemplates(lookupTemplateStrings) {
  lookupTemplateStrings.forEach(function(lookupTemplateString) {
    Ember.TEMPLATES[lookupTemplateString] = lookupTemplateString;
  });
}

const DiscourseResolver = buildResolver("discourse");

QUnit.module("lib:resolver", {
  beforeEach() {
    originalTemplates = Ember.TEMPLATES;
    Ember.TEMPLATES = {};

    resolver = DiscourseResolver.create();
  },

  afterEach() {
    Ember.TEMPLATES = originalTemplates;
  }
});

QUnit.test("finds templates in top level dir", assert => {
  setTemplates(["foobar", "fooBar", "foo_bar", "foo.bar"]);

  lookupTemplate(assert, "template:foobar", "foobar", "by lowcased name");
  lookupTemplate(assert, "template:fooBar", "fooBar", "by camel cased name");
  lookupTemplate(assert, "template:foo_bar", "foo_bar", "by underscored name");
  lookupTemplate(assert, "template:foo.bar", "foo.bar", "by dotted name");
});

QUnit.test("finds templates in first-level subdir", assert => {
  setTemplates(["foo/bar_baz"]);

  lookupTemplate(
    assert,
    "template:foo/bar_baz",
    "foo/bar_baz",
    "with subdir defined by slash"
  );
  lookupTemplate(
    assert,
    "template:foo.bar_baz",
    "foo/bar_baz",
    "with subdir defined by dot"
  );
  lookupTemplate(
    assert,
    "template:fooBarBaz",
    "foo/bar_baz",
    "with subdir defined by first camel case and the rest of camel cases converted to underscores"
  );
  lookupTemplate(
    assert,
    "template:foo_bar_baz",
    "foo/bar_baz",
    "with subdir defined by first underscore"
  );
});

QUnit.test(
  "resolves precedence between overlapping top level dir and first level subdir templates",
  assert => {
    setTemplates(["fooBar", "foo_bar", "foo.bar", "foo/bar"]);

    lookupTemplate(
      assert,
      "template:foo.bar",
      "foo/bar",
      "preferring first level subdir for dotted name"
    );
    lookupTemplate(
      assert,
      "template:fooBar",
      "fooBar",
      "preferring top level dir for camel cased name"
    );
    lookupTemplate(
      assert,
      "template:foo_bar",
      "foo_bar",
      "preferring top level dir for underscored name"
    );
  }
);

QUnit.test("finds templates in subdir deeper than one level", assert => {
  setTemplates(["foo/bar/baz/qux"]);

  lookupTemplate(
    assert,
    "template:foo/bar/baz/qux",
    "foo/bar/baz/qux",
    "for subdirs defined by slashes"
  );
  lookupTemplate(
    assert,
    "template:foo.bar.baz.qux",
    "foo/bar/baz/qux",
    "for subdirs defined by dots"
  );
  lookupTemplate(
    assert,
    "template:foo/bar/bazQux",
    "foo/bar/baz/qux",
    "for subdirs defined by slashes plus one camel case"
  );
  lookupTemplate(
    assert,
    "template:foo/bar/baz_qux",
    "foo/bar/baz/qux",
    "for subdirs defined by slashes plus one underscore"
  );

  lookupTemplate(
    assert,
    "template:fooBarBazQux",
    undefined,
    "but not for subdirs defined by more than one camel case"
  );
  lookupTemplate(
    assert,
    "template:foo_bar_baz_qux",
    undefined,
    "but not for subdirs defined by more than one underscore"
  );
  lookupTemplate(
    assert,
    "template:foo.bar.bazQux",
    undefined,
    "but not for subdirs defined by dots plus one camel case"
  );
  lookupTemplate(
    assert,
    "template:foo.bar.baz_qux",
    undefined,
    "but not for subdirs defined by dots plus one underscore"
  );
});

QUnit.test("resolves mobile templates to 'mobile/' namespace", assert => {
  setTemplates(["mobile/foo", "bar", "mobile/bar", "baz"]);

  setResolverOption("mobileView", true);

  lookupTemplate(
    assert,
    "template:foo",
    "mobile/foo",
    "finding mobile version even if normal one is not present"
  );
  lookupTemplate(
    assert,
    "template:bar",
    "mobile/bar",
    "preferring mobile version when both mobile and normal versions are present"
  );
  lookupTemplate(
    assert,
    "template:baz",
    "baz",
    "falling back to a normal version when mobile version is not present"
  );
});

QUnit.test("resolves plugin templates to 'javascripts/' namespace", assert => {
  setTemplates(["javascripts/foo", "bar", "javascripts/bar", "baz"]);

  lookupTemplate(
    assert,
    "template:foo",
    "javascripts/foo",
    "finding plugin version even if normal one is not present"
  );
  lookupTemplate(
    assert,
    "template:bar",
    "javascripts/bar",
    "preferring plugin version when both versions are present"
  );
  lookupTemplate(
    assert,
    "template:baz",
    "baz",
    "falling back to a normal version when plugin version is not present"
  );
});

QUnit.test(
  "resolves templates with 'admin' prefix to 'admin/templates/' namespace",
  assert => {
    setTemplates([
      "admin/templates/foo",
      "adminBar",
      "admin_bar",
      "admin.bar",
      "admin/templates/bar"
    ]);

    lookupTemplate(
      assert,
      "template:adminFoo",
      "admin/templates/foo",
      "when prefix is separated by camel case"
    );
    lookupTemplate(
      assert,
      "template:admin_foo",
      "admin/templates/foo",
      "when prefix is separated by underscore"
    );
    lookupTemplate(
      assert,
      "template:admin.foo",
      "admin/templates/foo",
      "when prefix is separated by dot"
    );

    lookupTemplate(
      assert,
      "template:adminfoo",
      undefined,
      "but not when prefix is not separated in any way"
    );
    lookupTemplate(
      assert,
      "template:adminBar",
      "adminBar",
      "but not when template with the exact camel cased name exists"
    );
    lookupTemplate(
      assert,
      "template:admin_bar",
      "admin_bar",
      "but not when template with the exact underscored name exists"
    );
    lookupTemplate(
      assert,
      "template:admin.bar",
      "admin.bar",
      "but not when template with the exact dotted name exists"
    );
  }
);

QUnit.test(
  "returns 'not_found' template when template name cannot be resolved",
  assert => {
    setTemplates(["not_found"]);

    lookupTemplate(assert, "template:foo/bar/baz", "not_found", "");
  }
);
