import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { defineBlockDataSource } from "discourse/blocks";
import { validateBlockDataOption } from "discourse/lib/blocks/-internals/validation/block-decorator";

module("Unit | Blocks | validation/data-option", function (hooks) {
  setupTest(hooks);

  function buildSource() {
    return defineBlockDataSource({ resolve: () => null });
  }

  module("source-backed declarations", function () {
    test("accepts request + source", function (assert) {
      // Should not throw: the source owns fetching, so no inline resolve is
      // needed.
      validateBlockDataOption("test-block", {
        request: () => ({}),
        source: buildSource(),
      });
      assert.true(true, "request + source accepted");
    });

    test("accepts request + source + skeleton", function (assert) {
      // Should not throw: skeleton stays a per-block presentation hint.
      validateBlockDataOption("test-block", {
        request: () => ({}),
        source: buildSource(),
        skeleton: () => ({ variant: "rect" }),
      });
      assert.true(true, "skeleton allowed alongside source");
    });

    test("request is still required with a source", function (assert) {
      assert.throws(
        () => validateBlockDataOption("test-block", { source: buildSource() }),
        /"data\.request" is required and must be a function/,
        "source without request rejected"
      );
    });

    test("rejects source combined with inline resolve", function (assert) {
      assert.throws(
        () =>
          validateBlockDataOption("test-block", {
            request: () => ({}),
            source: buildSource(),
            resolve: () => null,
          }),
        /"data\.resolve" must be declared on the block's data source/,
        "source + resolve rejected"
      );
    });

    test("rejects source combined with inline hydrate", function (assert) {
      assert.throws(
        () =>
          validateBlockDataOption("test-block", {
            request: () => ({}),
            source: buildSource(),
            hydrate: (raw) => raw,
          }),
        /"data\.hydrate" must be declared on the block's data source/,
        "source + hydrate rejected"
      );
    });

    test("rejects a source that was not created with defineBlockDataSource", function (assert) {
      assert.throws(
        () =>
          validateBlockDataOption("test-block", {
            request: () => ({}),
            source: { name: "fake", resolve: () => null },
          }),
        /"data\.source" must be a data source created with defineBlockDataSource/,
        "unbranded source rejected"
      );
    });
  });

  module("inline declarations (rejected)", function () {
    // Every data block now declares a source; the inline fetching form was
    // removed once the builtin and plugin blocks migrated.
    test("rejects an inline resolve without a source", function (assert) {
      assert.throws(
        () =>
          validateBlockDataOption("test-block", {
            request: () => ({}),
            resolve: () => null,
          }),
        /"data\.resolve" must be declared on the block's data source/,
        "inline resolve rejected"
      );
    });

    test("rejects an inline hydrate without a source", function (assert) {
      assert.throws(
        () =>
          validateBlockDataOption("test-block", {
            request: () => ({}),
            hydrate: (raw) => raw,
          }),
        /"data\.hydrate" must be declared on the block's data source/,
        "inline hydrate rejected"
      );
    });

    test("requires a source", function (assert) {
      assert.throws(
        () => validateBlockDataOption("test-block", { request: () => ({}) }),
        /"data\.source" is required/,
        "a declaration without a source is rejected"
      );
    });
  });
});
