import { module, test } from "qunit";
import {
  parseBlockName,
  parseBlockReference,
  VALID_BLOCK_NAME_PATTERN,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";

module("Unit | Lib | blocks/core/patterns", function () {
  module("VALID_BLOCK_NAME_PATTERN", function () {
    test("matches valid simple block names", function (assert) {
      assert.true(VALID_BLOCK_NAME_PATTERN.test("group"));
      assert.true(VALID_BLOCK_NAME_PATTERN.test("hero-banner"));
      assert.true(VALID_BLOCK_NAME_PATTERN.test("my-block-123"));
      assert.true(VALID_BLOCK_NAME_PATTERN.test("a"));
    });

    test("rejects invalid block names", function (assert) {
      assert.false(VALID_BLOCK_NAME_PATTERN.test(""));
      assert.false(VALID_BLOCK_NAME_PATTERN.test("123-block"));
      assert.false(VALID_BLOCK_NAME_PATTERN.test("-block"));
      assert.false(VALID_BLOCK_NAME_PATTERN.test("Block"));
      assert.false(VALID_BLOCK_NAME_PATTERN.test("my_block"));
      assert.false(VALID_BLOCK_NAME_PATTERN.test("my block"));
    });
  });

  module("VALID_NAMESPACED_BLOCK_PATTERN", function () {
    test("matches core block names (no namespace)", function (assert) {
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("group"));
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("hero-banner"));
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("my-block-123"));
    });

    test("matches plugin block names (namespace:name)", function (assert) {
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("chat:message-widget"));
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("my-plugin:my-block"));
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("a:b"));
    });

    test("matches theme block names (theme:namespace:name)", function (assert) {
      assert.true(
        VALID_NAMESPACED_BLOCK_PATTERN.test("theme:tactile:hero-banner")
      );
      assert.true(
        VALID_NAMESPACED_BLOCK_PATTERN.test("theme:my-theme:my-block")
      );
      assert.true(VALID_NAMESPACED_BLOCK_PATTERN.test("theme:a:b"));
    });

    test("rejects invalid namespaced names", function (assert) {
      // Uppercase not allowed
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("Theme:tactile:banner"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("theme:Tactile:banner"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("Chat:widget"));

      // theme: requires both namespace and name
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("theme:banner"));

      // Underscores not allowed
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("my_plugin:block"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("plugin:my_block"));

      // Empty segments not allowed
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test(":block"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("plugin:"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("theme::block"));

      // Numbers can't start segments
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("123:block"));
      assert.false(VALID_NAMESPACED_BLOCK_PATTERN.test("plugin:123block"));
    });
  });

  module("parseBlockName", function () {
    test("parses core block names", function (assert) {
      const result = parseBlockName("group");

      assert.deepEqual(result, {
        type: "core",
        namespace: null,
        name: "group",
      });
    });

    test("parses core block names with hyphens and numbers", function (assert) {
      const result = parseBlockName("hero-banner-123");

      assert.deepEqual(result, {
        type: "core",
        namespace: null,
        name: "hero-banner-123",
      });
    });

    test("parses plugin block names", function (assert) {
      const result = parseBlockName("chat:message-widget");

      assert.deepEqual(result, {
        type: "plugin",
        namespace: "chat",
        name: "message-widget",
      });
    });

    test("parses plugin block names with complex namespace", function (assert) {
      const result = parseBlockName("my-plugin-name:my-block");

      assert.deepEqual(result, {
        type: "plugin",
        namespace: "my-plugin-name",
        name: "my-block",
      });
    });

    test("parses theme block names", function (assert) {
      const result = parseBlockName("theme:tactile:hero-banner");

      assert.deepEqual(result, {
        type: "theme",
        namespace: "theme:tactile",
        name: "hero-banner",
      });
    });

    test("parses theme block names with complex namespace", function (assert) {
      const result = parseBlockName("theme:my-cool-theme:sidebar-widget");

      assert.deepEqual(result, {
        type: "theme",
        namespace: "theme:my-cool-theme",
        name: "sidebar-widget",
      });
    });

    test("returns null for invalid names", function (assert) {
      assert.strictEqual(parseBlockName(""), null);
      assert.strictEqual(parseBlockName("Invalid_Name"), null);
      assert.strictEqual(parseBlockName("Theme:name:block"), null);
      assert.strictEqual(parseBlockName("123:block"), null);
      assert.strictEqual(parseBlockName("theme:block"), null);
    });
  });

  module("parseBlockReference", function () {
    test("parses required block reference (no ? suffix)", function (assert) {
      const result = parseBlockReference("hero-banner");

      assert.deepEqual(result, {
        name: "hero-banner",
        optional: false,
      });
    });

    test("parses optional block reference (with ? suffix)", function (assert) {
      const result = parseBlockReference("hero-banner?");

      assert.deepEqual(result, {
        name: "hero-banner",
        optional: true,
      });
    });

    test("parses optional namespaced plugin block", function (assert) {
      const result = parseBlockReference("chat:widget?");

      assert.deepEqual(result, {
        name: "chat:widget",
        optional: true,
      });
    });

    test("parses optional namespaced theme block", function (assert) {
      const result = parseBlockReference("theme:tactile:banner?");

      assert.deepEqual(result, {
        name: "theme:tactile:banner",
        optional: true,
      });
    });

    test("parses required namespaced plugin block", function (assert) {
      const result = parseBlockReference("chat:widget");

      assert.deepEqual(result, {
        name: "chat:widget",
        optional: false,
      });
    });

    test("parses required namespaced theme block", function (assert) {
      const result = parseBlockReference("theme:tactile:banner");

      assert.deepEqual(result, {
        name: "theme:tactile:banner",
        optional: false,
      });
    });

    test("handles non-string input", function (assert) {
      const classRef = { blockName: "test" };
      const result = parseBlockReference(classRef);

      assert.deepEqual(result, {
        name: classRef,
        optional: false,
      });
    });
  });
});
