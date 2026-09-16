import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
// The public facade re-export is part of the contract: plugins import the
// factory from "discourse/blocks", never from the internal path.
import { defineBlockDataSource } from "discourse/blocks";
import { isBlockDataSource } from "discourse/lib/blocks/-internals/data-source";

module("Unit | Blocks | data-source", function (hooks) {
  setupTest(hooks);

  module("defineBlockDataSource", function () {
    test("returns a frozen, branded source preserving the given functions", function (assert) {
      const resolve = () => "value";
      const hydrate = (raw) => raw;

      const source = defineBlockDataSource({
        name: "topic-list",
        resolve,
        hydrate,
      });

      assert.true(isBlockDataSource(source), "the result is a data source");
      assert.true(Object.isFrozen(source), "the result is frozen");
      assert.strictEqual(source.name, "topic-list", "name is preserved");
      assert.strictEqual(source.resolve, resolve, "resolve is preserved");
      assert.strictEqual(source.hydrate, hydrate, "hydrate is preserved");
    });

    test("name is optional", function (assert) {
      const source = defineBlockDataSource({ resolve: () => null });

      assert.true(isBlockDataSource(source), "unnamed source is valid");

      // Normalized outside the assertion: either null or undefined counts as
      // "no name" for the block-name cache-key fallback.
      const normalizedName = source.name ?? null;
      assert.strictEqual(normalizedName, null, "name is absent");
    });

    test("accepts a batch-only source (no solo resolve)", function (assert) {
      const batchRequest = (descriptors) => ({ descriptors });
      const batchResolve = () => [];
      const batchExtract = () => null;

      const source = defineBlockDataSource({
        name: "batched",
        batch: {
          request: batchRequest,
          resolve: batchResolve,
          extract: batchExtract,
        },
      });

      assert.true(isBlockDataSource(source), "batch-only source is valid");
      assert.true(Object.isFrozen(source.batch), "batch is frozen too");
      assert.strictEqual(
        source.batch.request,
        batchRequest,
        "batch.request is preserved"
      );
      assert.strictEqual(
        source.batch.resolve,
        batchResolve,
        "batch.resolve is preserved"
      );
      assert.strictEqual(
        source.batch.extract,
        batchExtract,
        "batch.extract is preserved"
      );
    });

    test("accepts a source with both solo resolve and batch", function (assert) {
      const source = defineBlockDataSource({
        resolve: () => null,
        batch: {
          request: () => ({}),
          resolve: () => ({}),
          extract: () => null,
        },
      });

      assert.true(isBlockDataSource(source), "combined source is valid");
    });

    test("rejects a non-object config", function (assert) {
      assert.throws(
        () => defineBlockDataSource(null),
        /must be an object/,
        "null rejected"
      );
      assert.throws(
        () => defineBlockDataSource("topic-list"),
        /must be an object/,
        "string rejected"
      );
      assert.throws(
        () => defineBlockDataSource([]),
        /must be an object/,
        "array rejected"
      );
    });

    test("rejects a source declaring neither resolve nor batch", function (assert) {
      assert.throws(
        () => defineBlockDataSource({ name: "empty" }),
        /must declare "resolve" or "batch"/,
        "fetch-less source rejected"
      );
    });

    test("rejects an invalid name", function (assert) {
      assert.throws(
        () => defineBlockDataSource({ name: "", resolve: () => null }),
        /"name" must be a non-empty string/,
        "empty name rejected"
      );
      assert.throws(
        () => defineBlockDataSource({ name: 42, resolve: () => null }),
        /"name" must be a non-empty string/,
        "non-string name rejected"
      );
    });

    test("rejects non-function resolve and hydrate", function (assert) {
      assert.throws(
        () => defineBlockDataSource({ resolve: "nope" }),
        /"resolve" must be a function/,
        "non-function resolve rejected"
      );
      assert.throws(
        () => defineBlockDataSource({ resolve: () => null, hydrate: "nope" }),
        /"hydrate" must be a function/,
        "non-function hydrate rejected"
      );
    });

    test("rejects a malformed batch declaration", function (assert) {
      assert.throws(
        () => defineBlockDataSource({ batch: "nope" }),
        /"batch" must be an object/,
        "non-object batch rejected"
      );

      const validBatch = {
        request: () => ({}),
        resolve: () => ({}),
        extract: () => null,
      };

      for (const key of ["request", "resolve", "extract"]) {
        const batch = { ...validBatch };
        delete batch[key];

        assert.throws(
          () => defineBlockDataSource({ batch }),
          new RegExp(`"batch\\.${key}" is required and must be a function`),
          `batch without ${key} rejected`
        );
      }
    });

    test("rejects unknown keys", function (assert) {
      assert.throws(
        () => defineBlockDataSource({ resolve: () => null, request: () => 1 }),
        /unknown/i,
        "unknown top-level key rejected (request belongs to the block, not the source)"
      );
      assert.throws(
        () =>
          defineBlockDataSource({
            batch: {
              request: () => ({}),
              resolve: () => ({}),
              extract: () => null,
              hydrate: () => null,
            },
          }),
        /unknown/i,
        "unknown batch key rejected"
      );
    });
  });

  module("isBlockDataSource", function () {
    test("rejects non-source values", function (assert) {
      assert.false(isBlockDataSource(null), "null is not a source");
      assert.false(isBlockDataSource(undefined), "undefined is not a source");
      assert.false(isBlockDataSource("topic-list"), "string is not a source");
      assert.false(isBlockDataSource({}), "empty object is not a source");
      assert.false(
        isBlockDataSource({ name: "fake", resolve: () => null }),
        "structurally similar plain object is not a source"
      );
    });

    test("the brand does not survive a spread copy", function (assert) {
      const source = defineBlockDataSource({ resolve: () => null });

      // A copy did not go through validation, so it must not pass as a source
      // (the brand must be non-enumerable).
      assert.false(
        isBlockDataSource({ ...source }),
        "spread copy is not a source"
      );
    });
  });
});
