import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  applyLock,
  childOverridesFor,
  isPartKey,
  joinPartPath,
  parsePartKey,
  PART_KEY_SEGMENT,
  resolvePartArgs,
  splitPartPath,
  synthesizePartEntries,
} from "discourse/lib/blocks/-internals/composite";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

module("Unit | Lib | blocks/composite", function () {
  module("path utils", function () {
    test("joinPartPath drops empty segments", function (assert) {
      assert.strictEqual(joinPartPath("", "title"), "title");
      assert.strictEqual(joinPartPath("action", "label"), "action.label");
      assert.strictEqual(joinPartPath(null, "a", undefined, "b"), "a.b");
    });

    test("splitPartPath splits on dots", function (assert) {
      assert.deepEqual(splitPartPath("action.label"), ["action", "label"]);
      assert.deepEqual(splitPartPath(""), []);
      assert.deepEqual(splitPartPath(null), []);
    });

    test("isPartKey / parsePartKey round-trip", function (assert) {
      assert.false(isPartKey("42"));
      assert.true(isPartKey(`42${PART_KEY_SEGMENT}action`));

      assert.strictEqual(parsePartKey("42"), null);
      assert.deepEqual(
        parsePartKey(`42${PART_KEY_SEGMENT}action${PART_KEY_SEGMENT}label`),
        { compositeKey: "42", idPath: ["action", "label"] }
      );
    });
  });

  module("childOverridesFor", function () {
    test("splits own args from prefix-stripped nested overrides", function (assert) {
      const overrides = {
        title: { text: "Hi" },
        action: { background: "#fff" },
        "action.label": { text: "Buy" },
        "action.icon": { name: "tag" },
      };

      assert.deepEqual(childOverridesFor(overrides, "title"), {
        own: { text: "Hi" },
        nested: undefined,
      });

      assert.deepEqual(childOverridesFor(overrides, "action"), {
        own: { background: "#fff" },
        nested: { label: { text: "Buy" }, icon: { name: "tag" } },
      });
    });

    test("handles missing overrides", function (assert) {
      assert.deepEqual(childOverridesFor(undefined, "x"), {
        own: undefined,
        nested: undefined,
      });
    });
  });

  module("applyLock", function () {
    test("true locks the whole part", function (assert) {
      assert.strictEqual(applyLock({ a: 1 }, true), undefined);
    });

    test("array drops named args only", function (assert) {
      assert.deepEqual(applyLock({ a: 1, b: 2 }, ["a"]), { b: 2 });
    });

    test("no lock keeps everything", function (assert) {
      assert.deepEqual(applyLock({ a: 1 }, null), { a: 1 });
    });
  });

  module("resolvePartArgs", function () {
    test("merges defaults with lock-filtered override", function (assert) {
      const part = {
        args: { label: "Default", variant: "primary" },
        lock: ["variant"],
      };
      assert.deepEqual(
        resolvePartArgs(part, { label: "Buy", variant: "danger" }),
        { label: "Buy", variant: "primary" },
        "override applies to label, locked variant keeps the default"
      );
    });

    test("returns a copy of defaults when no override", function (assert) {
      const part = { args: { label: "Default" } };
      const result = resolvePartArgs(part, undefined);
      assert.deepEqual(result, { label: "Default" });
      assert.notStrictEqual(
        result,
        part.args,
        "does not alias the frozen defaults"
      );
    });
  });

  module("synthesizePartEntries", function () {
    test("synthesizes direct parts with derived keys and markers", function (assert) {
      @block("composite-test:card", {
        parts: [
          { id: "title", block: "heading", args: { text: "Hi", level: 2 } },
          { id: "body", block: "paragraph", args: { text: "Body" } },
        ],
      })
      class Card extends Component {}

      const metadata = getBlockMetadata(Card);
      const entry = {
        block: "composite-test:card",
        __stableKey: 42,
        overrides: { title: { text: "Edited" } },
      };

      const parts = synthesizePartEntries(entry, metadata);

      assert.strictEqual(parts.length, 2);
      assert.deepEqual(parts[0].args, { text: "Edited", level: 2 });
      assert.strictEqual(parts[0].__partId, "title");
      assert.strictEqual(parts[0].__partPath, "title");
      assert.strictEqual(parts[0].__compositeKey, "42");
      assert.true(parts[0].__fromComposite);
      assert.true(parts[0].__visible);
      assert.strictEqual(
        parts[0].__stableKey,
        `42${PART_KEY_SEGMENT}title`,
        "derived key encodes composite + id path"
      );
      // Untouched part falls back to its code default.
      assert.deepEqual(parts[1].args, { text: "Body" });
    });

    test("passes prefix-stripped overrides down for nested composites", function (assert) {
      @block("composite-test:outer", {
        parts: [{ id: "action", block: "wf:cta-actions" }],
      })
      class Outer extends Component {}

      const metadata = getBlockMetadata(Outer);
      const entry = {
        block: "composite-test:outer",
        __stableKey: 7,
        overrides: {
          action: { gap: "lg" },
          "action.primary": { label: "Buy" },
          "action.primary.icon": { name: "cart" },
        },
      };

      const [actionPart] = synthesizePartEntries(entry, metadata);

      assert.deepEqual(actionPart.args, { gap: "lg" }, "own override applied");
      assert.deepEqual(
        actionPart.overrides,
        { primary: { label: "Buy" }, "primary.icon": { name: "cart" } },
        "deeper overrides flow down with the part prefix stripped"
      );
      assert.strictEqual(actionPart.__partPath, "action");
      assert.strictEqual(actionPart.__compositeKey, "7");
      assert.strictEqual(actionPart.__stableKey, `7${PART_KEY_SEGMENT}action`);

      // Re-synthesizing one level deeper (as the child walk does) keeps the
      // outermost composite key and accumulates the id path — proving nesting
      // needs no special casing.
      @block("composite-test:inner", {
        parts: [{ id: "primary", block: "button-link", args: { href: "#" } }],
      })
      class Inner extends Component {}
      const [deep] = synthesizePartEntries(actionPart, getBlockMetadata(Inner));
      assert.strictEqual(deep.__partPath, "action.primary");
      assert.strictEqual(
        deep.__compositeKey,
        "7",
        "outermost composite key preserved"
      );
      assert.deepEqual(
        deep.args,
        { href: "#", label: "Buy" },
        "deep override applied"
      );
      assert.strictEqual(
        deep.__stableKey,
        `7${PART_KEY_SEGMENT}action${PART_KEY_SEGMENT}primary`
      );
    });
  });

  module("decorator validation", function () {
    test("rejects duplicate part ids", function (assert) {
      assert.throws(() => {
        @block("composite-test:dupe", {
          parts: [
            { id: "a", block: "heading" },
            { id: "a", block: "paragraph" },
          ],
        })
        // eslint-disable-next-line no-unused-vars
        class Dupe extends Component {}
      }, /duplicate part id/i);
    });

    test("rejects a part id containing a dot", function (assert) {
      assert.throws(() => {
        @block("composite-test:dotted", {
          parts: [{ id: "a.b", block: "heading" }],
        })
        // eslint-disable-next-line no-unused-vars
        class Dotted extends Component {}
      }, /must not contain/i);
    });

    test("rejects a part without a block", function (assert) {
      assert.throws(() => {
        @block("composite-test:noblock", {
          parts: [{ id: "a" }],
        })
        // eslint-disable-next-line no-unused-vars
        class NoBlock extends Component {}
      }, /requires a "block"/i);
    });

    test("rejects an invalid lock", function (assert) {
      assert.throws(() => {
        @block("composite-test:badlock", {
          parts: [{ id: "a", block: "heading", lock: "variant" }],
        })
        // eslint-disable-next-line no-unused-vars
        class BadLock extends Component {}
      }, /"lock" must be/i);
    });

    test("a parts block is treated as a container", function (assert) {
      @block("composite-test:iscontainer", {
        parts: [{ id: "a", block: "heading" }],
      })
      class IsContainer extends Component {}

      assert.true(getBlockMetadata(IsContainer).isContainer);
      assert.strictEqual(getBlockMetadata(IsContainer).parts.length, 1);
    });
  });
});
