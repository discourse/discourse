import { buildResolver, setResolverOption } from "discourse-common/resolver";
import { module, test } from "qunit";

let originalTemplates;
let resolver;

function lookupTemplate(assert, name, expectedTemplate, message) {
  let parseName = resolver.parseName(name);
  let result = resolver.resolveTemplate(parseName);
  assert.strictEqual(result, expectedTemplate, message);
}

function setTemplates(lookupTemplateStrings) {
  lookupTemplateStrings.forEach(function (lookupTemplateString) {
    // eslint-disable-next-line no-undef
    Ember.TEMPLATES[lookupTemplateString] = lookupTemplateString;
  });
}

const DiscourseResolver = buildResolver("discourse");

module("Unit | Ember | resolver", function (hooks) {
  hooks.beforeEach(function () {
    // eslint-disable-next-line no-undef
    originalTemplates = Ember.TEMPLATES;
    // eslint-disable-next-line no-undef
    Ember.TEMPLATES = {};

    resolver = DiscourseResolver.create({
      namespace: { modulePrefix: "discourse" },
    });
  });

  hooks.afterEach(function () {
    // eslint-disable-next-line no-undef
    Ember.TEMPLATES = originalTemplates;
  });

  test("finds templates in top level dir", function (assert) {
    setTemplates(["foobar", "fooBar", "foo_bar", "foo.bar"]);

    // Default unmodified behavior
    lookupTemplate(assert, "template:foobar", "foobar", "by lowcased name");

    // Default unmodified behavior
    lookupTemplate(assert, "template:fooBar", "fooBar", "by camel cased name");

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foo_bar",
      "foo_bar",
      "by underscored name"
    );

    // Default unmodified behavior
    lookupTemplate(assert, "template:foo.bar", "foo.bar", "by dotted name");
  });

  test("finds templates in first-level subdir", function (assert) {
    setTemplates(["foo/bar_baz"]);

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foo/bar_baz",
      "foo/bar_baz",
      "with subdir defined by slash"
    );

    // Convert dots to slash
    lookupTemplate(
      assert,
      "template:foo.bar_baz",
      "foo/bar_baz",
      "with subdir defined by dot"
    );

    // Convert dashes to slash
    lookupTemplate(
      assert,
      "template:foo-bar_baz",
      "foo/bar_baz",
      "with subdir defined by dash"
    );

    // Underscored with first segment as directory
    lookupTemplate(
      assert,
      "template:fooBarBaz",
      "foo/bar_baz",
      "with subdir defined by first camel case and the rest of camel cases converted to underscores"
    );

    // Already underscored with first segment as directory
    lookupTemplate(
      assert,
      "template:foo_bar_baz",
      "foo/bar_baz",
      "with subdir defined by first underscore"
    );
  });

  test("resolves precedence between overlapping top level dir and first level subdir templates", function (assert) {
    setTemplates(["fooBar", "foo_bar", "foo.bar", "foo/bar", "baz/qux"]);

    // Directories are prioritized when dotted
    lookupTemplate(
      assert,
      "template:foo.bar",
      "foo/bar",
      "preferring first level subdir for dotted name"
    );

    // Directories are prioritized when dashed
    lookupTemplate(
      assert,
      "template:foo-bar",
      "foo/bar",
      "preferring first level subdir for dotted name"
    );

    // Default unmodified before directories, except when dotted
    lookupTemplate(
      assert,
      "template:fooBar",
      "fooBar",
      "preferring top level dir for camel cased name"
    );

    // Default unmodified before directories, except when dotted
    lookupTemplate(
      assert,
      "template:foo_bar",
      "foo_bar",
      "preferring top level dir for underscored name"
    );

    // Use directory version if top-level isn't found
    lookupTemplate(
      assert,
      "template:baz-qux",
      "baz/qux",
      "fallback subdir for dashed name"
    );
  });

  test("finds templates in subdir deeper than one level", function (assert) {
    setTemplates(["foo/bar/baz/qux"]);

    // Default unmodified
    lookupTemplate(
      assert,
      "template:foo/bar/baz/qux",
      "foo/bar/baz/qux",
      "for subdirs defined by slashes"
    );

    // Converts dotted to slashed
    lookupTemplate(
      assert,
      "template:foo.bar.baz.qux",
      "foo/bar/baz/qux",
      "for subdirs defined by dots"
    );

    // Converts first camelized segment to slashed
    lookupTemplate(
      assert,
      "template:foo/bar/bazQux",
      "foo/bar/baz/qux",
      "for subdirs defined by slashes plus one camel case"
    );

    // Converts first underscore to slashed
    lookupTemplate(
      assert,
      "template:foo/bar/baz_qux",
      "foo/bar/baz/qux",
      "for subdirs defined by slashes plus one underscore"
    );

    // Only converts first camelized segment to slashed so this isn't matched
    lookupTemplate(
      assert,
      "template:fooBarBazQux",
      undefined,
      "but not for subdirs defined by more than one camel case"
    );

    // Only converts first underscored segment to slashed so this isn't matched
    lookupTemplate(
      assert,
      "template:foo_bar_baz_qux",
      undefined,
      "but not for subdirs defined by more than one underscore"
    );

    // Only converts dots to slashes OR first camelized segment. This has both so isn't matched.
    lookupTemplate(
      assert,
      "template:foo.bar.bazQux",
      undefined,
      "but not for subdirs defined by dots plus one camel case"
    );

    // Only converts dots to slashes OR first underscored segment. This has both so isn't matched.
    lookupTemplate(
      assert,
      "template:foo.bar.baz_qux",
      undefined,
      "but not for subdirs defined by dots plus one underscore"
    );
  });

  test("resolves mobile templates to 'mobile/' namespace", function (assert) {
    setTemplates(["mobile/foo", "bar", "mobile/bar", "baz"]);

    setResolverOption("mobileView", true);

    // Default with mobile/ added
    lookupTemplate(
      assert,
      "template:foo",
      "mobile/foo",
      "finding mobile version even if normal one is not present"
    );

    // Default with mobile preferred
    lookupTemplate(
      assert,
      "template:bar",
      "mobile/bar",
      "preferring mobile version when both mobile and normal versions are present"
    );

    // Default when mobile not present
    lookupTemplate(
      assert,
      "template:baz",
      "baz",
      "falling back to a normal version when mobile version is not present"
    );
  });

  test("resolves plugin templates to 'javascripts/' namespace", function (assert) {
    setTemplates(["javascripts/foo", "bar", "javascripts/bar", "baz"]);

    // Default with javascripts/ added
    lookupTemplate(
      assert,
      "template:foo",
      "javascripts/foo",
      "finding plugin version even if normal one is not present"
    );

    // Default with javascripts/ added, takes precedence
    lookupTemplate(
      assert,
      "template:bar",
      "javascripts/bar",
      "preferring plugin version when both versions are present"
    );

    // Default when javascripts version not present
    lookupTemplate(
      assert,
      "template:baz",
      "baz",
      "falling back to a normal version when plugin version is not present"
    );
  });

  test("resolves plugin mobile templates to 'javascripts/mobile/' namespace", function (assert) {
    setTemplates([
      "javascripts/mobile/foo",
      "javascripts/mobile/bar",
      "javascripts/bar",
      "javascripts/mobile/baz",
      "mobile/baz",
    ]);

    setResolverOption("mobileView", true);

    // Default with javascripts/mobile/ added
    lookupTemplate(
      assert,
      "template:foo",
      "javascripts/mobile/foo",
      "finding plugin version even if normal one is not present"
    );

    // Default with javascripts/mobile added, takes precedence over non-mobile
    lookupTemplate(
      assert,
      "template:bar",
      "javascripts/mobile/bar",
      "preferring plugin mobile version when both non-mobile plugin version is also present"
    );

    // Default with javascripts/mobile when non-plugin mobile version is present
    lookupTemplate(
      assert,
      "template:baz",
      "javascripts/mobile/baz",
      "preferring plugin mobile version over non-plugin mobile version"
    );
  });

  test("resolves templates with 'admin' prefix", function (assert) {
    setTemplates([
      "admin/templates/foo",
      "adminBar",
      "admin_bar",
      "admin.bar",
      "admin/templates/bar",
      "admin/templates/dashboard_general",
      "admin-baz-qux",
      "javascripts/admin/plugin-template",
    ]);

    // Switches prefix to admin/templates when camelized
    lookupTemplate(
      assert,
      "template:adminFoo",
      "admin/templates/foo",
      "when prefix is separated by camel case"
    );

    // Switches prefix to admin/templates when underscored
    lookupTemplate(
      assert,
      "template:admin_foo",
      "admin/templates/foo",
      "when prefix is separated by underscore"
    );

    // Switches prefix to admin/templates when dotted
    lookupTemplate(
      assert,
      "template:admin.foo",
      "admin/templates/foo",
      "when prefix is separated by dot"
    );

    // Doesn't match unseparated prefix
    lookupTemplate(
      assert,
      "template:adminfoo",
      undefined,
      "but not when prefix is not separated in any way"
    );

    // Prioritized the default match when camelized
    lookupTemplate(
      assert,
      "template:adminBar",
      "adminBar",
      "but not when template with the exact camel cased name exists"
    );

    // Prioritized the default match when underscored
    lookupTemplate(
      assert,
      "template:admin_bar",
      "admin_bar",
      "but not when template with the exact underscored name exists"
    );

    // Prioritized the default match when dotted
    lookupTemplate(
      assert,
      "template:admin.bar",
      "admin.bar",
      "but not when template with the exact dotted name exists"
    );

    lookupTemplate(
      assert,
      "template:admin-dashboard-general",
      "admin/templates/dashboard_general",
      "finds namespaced and underscored version"
    );

    lookupTemplate(
      assert,
      "template:admin-baz/qux",
      "admin-baz-qux",
      "also tries dasherized"
    );

    lookupTemplate(
      assert,
      "template:admin-plugin/template",
      "javascripts/admin/plugin-template",
      "looks up templates in plugins"
    );
  });

  test("resolves component templates with 'admin' prefix to 'admin/templates/' namespace", function (assert) {
    setTemplates([
      "admin/templates/components/foo",
      "components/bar",
      "admin/templates/components/bar",
    ]);

    // Looks for components in admin/templates
    lookupTemplate(
      assert,
      "template:components/foo",
      "admin/templates/components/foo",
      "uses admin template component when no standard match"
    );

    // Prioritized non-admin component
    lookupTemplate(
      assert,
      "template:components/bar",
      "components/bar",
      "uses standard match when both exist"
    );
  });

  // We can probably remove this in the future since this behavior seems pretty
  // close to Ember's default behavior.
  // See https://guides.emberjs.com/release/routing/loading-and-error-substates/
  test("resolves loading templates", function (assert) {
    setTemplates(["fooloading", "foo/loading", "foo_loading", "loading"]);

    lookupTemplate(
      assert,
      "template:fooloading",
      "fooloading",
      "exact match without separator"
    );

    lookupTemplate(
      assert,
      "template:foo/loading",
      "foo/loading",
      "exact match with slash"
    );

    lookupTemplate(
      assert,
      "template:foo_loading",
      "foo_loading",
      "exact match underscore"
    );

    lookupTemplate(
      assert,
      "template:barloading",
      "loading",
      "fallback without separator"
    );

    lookupTemplate(
      assert,
      "template:bar/loading",
      "loading",
      "fallback with slash"
    );

    lookupTemplate(
      assert,
      "template:bar.loading",
      "loading",
      "fallback with dot"
    );

    lookupTemplate(
      assert,
      "template:bar_loading",
      "loading",
      "fallback underscore"
    );

    // TODO: Maybe test precedence
  });

  test("resolves connector templates", function (assert) {
    setTemplates([
      "javascripts/foo",
      "javascripts/connectors/foo-bar/baz_qux",
      "javascripts/connectors/foo-bar/camelCase",
    ]);

    lookupTemplate(
      assert,
      "template:connectors/foo",
      "javascripts/foo",
      "looks up in javascripts/ namespace"
    );

    lookupTemplate(
      assert,
      "template:connectors/components/foo",
      "javascripts/foo",
      "removes components segment"
    );

    lookupTemplate(
      assert,
      "template:connectors/foo-bar/baz-qux",
      "javascripts/connectors/foo-bar/baz_qux",
      "underscores last segment"
    );

    lookupTemplate(
      assert,
      "template:connectors/foo-bar/camelCase",
      "javascripts/connectors/foo-bar/camelCase",
      "handles camelcase file names"
    );

    lookupTemplate(
      assert,
      resolver.normalize("template:connectors/foo-bar/camelCase"),
      "javascripts/connectors/foo-bar/camelCase",
      "handles camelcase file names when normalized"
    );
  });

  test("returns 'not_found' template when template name cannot be resolved", function (assert) {
    setTemplates(["not_found"]);

    lookupTemplate(assert, "template:foo/bar/baz", "not_found", "");
  });

  test("resolves templates with 'wizard' prefix", function (assert) {
    setTemplates([
      "wizard/templates/foo",
      "wizard_bar",
      "wizard.bar",
      "wizard/templates/bar",
      "wizard/templates/dashboard_general",
      "wizard-baz-qux",
      "javascripts/wizard/plugin-template",
    ]);

    // Switches prefix to wizard/templates when underscored
    lookupTemplate(
      assert,
      "template:wizard_foo",
      "wizard/templates/foo",
      "when prefix is separated by underscore"
    );

    // Switches prefix to wizard/templates when dotted
    lookupTemplate(
      assert,
      "template:wizard.foo",
      "wizard/templates/foo",
      "when prefix is separated by dot"
    );

    // Doesn't match unseparated prefix
    lookupTemplate(
      assert,
      "template:wizardfoo",
      undefined,
      "but not when prefix is not separated in any way"
    );

    // Prioritized the default match when underscored
    lookupTemplate(
      assert,
      "template:wizard_bar",
      "wizard_bar",
      "but not when template with the exact underscored name exists"
    );

    // Prioritized the default match when dotted
    lookupTemplate(
      assert,
      "template:wizard.bar",
      "wizard.bar",
      "but not when template with the exact dotted name exists"
    );

    lookupTemplate(
      assert,
      "template:wizard-dashboard-general",
      "wizard/templates/dashboard_general",
      "finds namespaced and underscored version"
    );

    lookupTemplate(
      assert,
      "template:wizard-baz/qux",
      "wizard-baz-qux",
      "also tries dasherized"
    );
  });

  test("resolves component templates with 'wizard' prefix to 'wizard/templates/' namespace", function (assert) {
    setTemplates([
      "wizard/templates/components/foo",
      "components/bar",
      "wizard/templates/components/bar",
    ]);

    // Looks for components in wizard/templates
    lookupTemplate(
      assert,
      "template:components/foo",
      "wizard/templates/components/foo",
      "uses wizard template component when no standard match"
    );

    // Prioritized non-wizard component
    lookupTemplate(
      assert,
      "template:components/bar",
      "components/bar",
      "uses standard match when both exist"
    );
  });
});
