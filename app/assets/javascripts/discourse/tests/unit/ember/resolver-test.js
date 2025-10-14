import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import DiscourseTemplateMap from "discourse/lib/discourse-template-map";
import { buildResolver } from "discourse/resolver";
import { registerTemporaryModule } from "discourse/tests/helpers/temporary-module-helper";

let resolver;

function lookupTemplate(assert, name, expectedTemplate, message) {
  let parseName = resolver.parseName(name);
  let result = resolver.resolveTemplate(parseName);
  assert.strictEqual(result, expectedTemplate, message);
}

function resolve(name) {
  return resolver.resolve(name);
}

function setTemplates(templateModuleNames) {
  for (const name of templateModuleNames) {
    registerTemporaryModule(name, name);
  }
}

const DiscourseResolver = buildResolver("discourse");

module("Unit | Ember | resolver", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    DiscourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
    resolver = DiscourseResolver.create({
      namespace: { modulePrefix: "discourse" },
    });
  });

  test("finds templates in top level dir", function (assert) {
    setTemplates([
      "discourse/templates/foobar",
      "discourse/templates/fooBar",
      "discourse/templates/foo_bar",
      "discourse/templates/foo.bar",
    ]);

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foobar",
      "discourse/templates/foobar",
      "by lowcased name"
    );

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:fooBar",
      "discourse/templates/fooBar",
      "by camel cased name"
    );

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foo_bar",
      "discourse/templates/foo_bar",
      "by underscored name"
    );

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foo.bar",
      "discourse/templates/foo.bar",
      "by dotted name"
    );
  });

  test("finds templates in first-level subdir", function (assert) {
    setTemplates(["discourse/templates/foo/bar_baz"]);

    // Default unmodified behavior
    lookupTemplate(
      assert,
      "template:foo/bar_baz",
      "discourse/templates/foo/bar_baz",
      "with subdir defined by slash"
    );

    // Convert dots to slash
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo.bar_baz",
          "discourse/templates/foo/bar_baz",
          "with subdir defined by dot"
        );
      }
    );

    // Convert dashes to slash
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo-bar_baz",
          "discourse/templates/foo/bar_baz",
          "with subdir defined by dash"
        );
      }
    );

    // Underscored with first segment as directory
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:fooBarBaz",
          "discourse/templates/foo/bar_baz",
          "with subdir defined by first camel case and the rest of camel cases converted to underscores"
        );
      }
    );

    // Already underscored with first segment as directory
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo_bar_baz",
          "discourse/templates/foo/bar_baz",
          "with subdir defined by first underscore"
        );
      }
    );
  });

  test("resolves precedence between overlapping top level dir and first level subdir templates", function (assert) {
    setTemplates([
      "discourse/templates/fooBar",
      "discourse/templates/foo_bar",
      "discourse/templates/foo.bar",
      "discourse/templates/foo/bar",
      "discourse/templates/baz/qux",
    ]);

    // Directories are prioritized when dotted
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo.bar",
          "discourse/templates/foo/bar",
          "preferring first level subdir for dotted name"
        );
      }
    );

    // Directories are prioritized when dashed
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo-bar",
          "discourse/templates/foo/bar",
          "preferring first level subdir for dotted name"
        );
      }
    );

    // Default unmodified before directories, except when dotted
    lookupTemplate(
      assert,
      "template:fooBar",
      "discourse/templates/fooBar",
      "preferring top level dir for camel cased name"
    );

    // Default unmodified before directories, except when dotted
    lookupTemplate(
      assert,
      "template:foo_bar",
      "discourse/templates/foo_bar",
      "preferring top level dir for underscored name"
    );

    // Use directory version if top-level isn't found
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:baz-qux",
          "discourse/templates/baz/qux",
          "fallback subdir for dashed name"
        );
      }
    );
  });

  test("finds templates in subdir deeper than one level", function (assert) {
    setTemplates(["discourse/templates/foo/bar/baz/qux"]);

    // Default unmodified
    lookupTemplate(
      assert,
      "template:foo/bar/baz/qux",
      "discourse/templates/foo/bar/baz/qux",
      "for subdirs defined by slashes"
    );

    // Converts dotted to slashed
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo.bar.baz.qux",
          "discourse/templates/foo/bar/baz/qux",
          "for subdirs defined by dots"
        );
      }
    );

    // Converts first camelized segment to slashed
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo/bar/bazQux",
          "discourse/templates/foo/bar/baz/qux",
          "for subdirs defined by slashes plus one camel case"
        );
      }
    );

    // Converts first underscore to slashed
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:foo/bar/baz_qux",
          "discourse/templates/foo/bar/baz/qux",
          "for subdirs defined by slashes plus one underscore"
        );
      }
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

  test("resolves templates to plugin and theme namespaces", function (assert) {
    setTemplates([
      "discourse/plugins/my-plugin/discourse/templates/foo",
      "discourse/theme-12/discourse/templates/baz",
      "discourse/templates/qux",
    ]);

    // Defined in plugin
    lookupTemplate(
      assert,
      "template:foo",
      "discourse/plugins/my-plugin/discourse/templates/foo",
      "finding plugin version even if normal one is not present"
    );

    // Defined in theme
    withSilencedDeprecations("discourse.resolver-template-overrides", () => {
      lookupTemplate(
        assert,
        "template:baz",
        "discourse/theme-12/discourse/templates/baz",
        "prefers theme version over plugin and core"
      );
    });

    // Defined in core
    lookupTemplate(
      assert,
      "template:qux",
      "discourse/templates/qux",
      "uses core if there are no theme/plugin definitions"
    );
  });

  test("resolves templates with 'admin' prefix", function (assert) {
    setTemplates([
      "admin/templates/foo",
      "discourse/templates/adminBar",
      "discourse/templates/admin_bar",
      "discourse/templates/admin.bar",
      "admin/templates/bar",
      "admin/templates/dashboard_general",
      "discourse/templates/admin-baz-qux",
      "discourse/plugins/my-plugin/discourse/templates/admin/plugin-template",
      "admin/templates/components/my-admin-component",
    ]);

    // Switches prefix to admin/templates when camelized
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:adminFoo",
          "admin/templates/foo",
          "when prefix is separated by camel case"
        );
      }
    );

    // Switches prefix to admin/templates when underscored
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:admin_foo",
          "admin/templates/foo",
          "when prefix is separated by underscore"
        );
      }
    );

    // Switches prefix to admin/templates when dotted
    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:admin.foo",
          "admin/templates/foo",
          "when prefix is separated by dot"
        );
      }
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
      "discourse/templates/adminBar",
      "but not when template with the exact camel cased name exists"
    );

    // Prioritized the default match when underscored
    lookupTemplate(
      assert,
      "template:admin_bar",
      "discourse/templates/admin_bar",
      "but not when template with the exact underscored name exists"
    );

    // Prioritized the default match when dotted
    lookupTemplate(
      assert,
      "template:admin.bar",
      "discourse/templates/admin.bar",
      "but not when template with the exact dotted name exists"
    );

    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:admin-baz/qux",
          "discourse/templates/admin-baz-qux",
          "also tries dasherized"
        );
      }
    );

    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:admin-plugin/template",
          "discourse/plugins/my-plugin/discourse/templates/admin/plugin-template",
          "looks up templates in plugins"
        );
      }
    );

    lookupTemplate(
      assert,
      "template:foo",
      "admin/templates/foo",
      "will return admin templates for regular controllers, if no normal match exists"
    );

    lookupTemplate(
      assert,
      "template:components/my-admin-component",
      "admin/templates/components/my-admin-component",
      "returns admin-defined component templates"
    );
  });

  test("resolves component templates with 'admin' prefix to 'admin/templates/' namespace", function (assert) {
    setTemplates([
      "admin/templates/components/foo",
      "discourse/templates/components/bar",
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
      "discourse/templates/components/bar",
      "uses standard match when both exist"
    );
  });

  // We can probably remove this in the future since this behavior seems pretty
  // close to Ember's default behavior.
  // See https://guides.emberjs.com/release/routing/loading-and-error-substates/
  test("resolves loading templates", function (assert) {
    setTemplates([
      "discourse/templates/fooloading",
      "discourse/templates/foo/loading",
      "discourse/templates/foo_loading",
      "discourse/templates/loading",
    ]);

    lookupTemplate(
      assert,
      "template:fooloading",
      "discourse/templates/fooloading",
      "exact match without separator"
    );

    lookupTemplate(
      assert,
      "template:foo/loading",
      "discourse/templates/foo/loading",
      "exact match with slash"
    );

    lookupTemplate(
      assert,
      "template:foo_loading",
      "discourse/templates/foo_loading",
      "exact match underscore"
    );

    lookupTemplate(
      assert,
      "template:barloading",
      "discourse/templates/loading",
      "fallback without separator"
    );

    lookupTemplate(
      assert,
      "template:bar/loading",
      "discourse/templates/loading",
      "fallback with slash"
    );

    lookupTemplate(
      assert,
      "template:bar.loading",
      "discourse/templates/loading",
      "fallback with dot"
    );

    lookupTemplate(
      assert,
      "template:bar_loading",
      "discourse/templates/loading",
      "fallback underscore"
    );

    // TODO: Maybe test precedence
  });

  test("resolves connector templates", function (assert) {
    setTemplates([
      "discourse/plugins/my-plugin/discourse/templates/foo",
      "discourse/plugins/my-plugin/discourse/templates/connectors/foo-bar/baz_qux",
      "discourse/plugins/my-plugin/discourse/templates/connectors/foo-bar/camelCase",
    ]);

    lookupTemplate(
      assert,
      "template:connectors/foo",
      "discourse/plugins/my-plugin/discourse/templates/foo",
      "looks up in plugin namespace"
    );

    lookupTemplate(
      assert,
      "template:connectors/components/foo",
      "discourse/plugins/my-plugin/discourse/templates/foo",
      "removes components segment"
    );

    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          "template:connectors/foo-bar/baz-qux",
          "discourse/plugins/my-plugin/discourse/templates/connectors/foo-bar/baz_qux",
          "underscores last segment"
        );
      }
    );

    lookupTemplate(
      assert,
      "template:connectors/foo-bar/camelCase",
      "discourse/plugins/my-plugin/discourse/templates/connectors/foo-bar/camelCase",
      "handles camelcase file names"
    );

    withSilencedDeprecations(
      "discourse.deprecated-resolver-normalization",
      () => {
        lookupTemplate(
          assert,
          resolver.normalize("template:connectors/foo-bar/camelCase"),
          "discourse/plugins/my-plugin/discourse/templates/connectors/foo-bar/camelCase",
          "handles camelcase file names when normalized"
        );
      }
    );
  });

  test("returns 'not_found' template when template name cannot be resolved", function (assert) {
    setTemplates(["discourse/templates/not_found"]);

    lookupTemplate(
      assert,
      "template:foo/bar/baz",
      "discourse/templates/not_found",
      ""
    );
  });

  test("resolves plugin/theme components with and without /index", function (assert) {
    registerTemporaryModule(
      "discourse/plugins/my-fake-plugin/discourse/components/my-component",
      "my-component"
    );
    registerTemporaryModule(
      "discourse/plugins/my-fake-plugin/discourse/components/my-second-component/index",
      "my-second-component"
    );

    assert.strictEqual(resolve("component:my-component"), "my-component");
    assert.strictEqual(
      resolve("component:my-second-component"),
      "my-second-component"
    );
  });
});
