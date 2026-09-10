import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import Card from "discourse/blocks/builtin/card";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import {
  collectEntryFailures,
  validateLayout,
} from "discourse/lib/blocks/-internals/validation/layout";
import {
  friendlyEntryMessages,
  friendlyErrorMessage,
} from "discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message";

@block("wf-fem-leaf")
class LeafBlock extends Component {
  <template>x</template>
}

/**
 * Runs the permissive+collect layout validation the editor uses, so a
 * per-entry structural failure is stamped onto the entry (`__failureReason`
 * / `__failureDetails`) instead of aborting.
 */
async function validatePermissively(owner, entry) {
  const blocksService = owner.lookup("service:blocks");
  await validateLayout(
    [entry],
    "homepage-blocks",
    blocksService,
    "",
    null,
    null,
    null,
    null,
    0,
    { seenIds: new Map(), permissive: true, collect: true, warnings: [] }
  );
}

module("Unit | Lib | friendly-error-message", function (hooks) {
  setupTest(hooks);

  test("custom field diagnostics keep different messages for the same field independently keyed", function (assert) {
    const entry = { block: Card, args: { actionLabel: "Visit", href: 123 } };
    const details = collectEntryFailures(entry, Card);
    const result = friendlyEntryMessages({ __failureDetails: details });

    assert.strictEqual(
      result.length,
      2,
      "both schema and completeness errors survive"
    );
    assert.strictEqual(
      new Set(result.map(({ text }) => text)).size,
      2,
      "the same field has two different instructions"
    );
    assert.strictEqual(
      new Set(result.map(({ id }) => id)).size,
      2,
      "different instructions for the same field have unique keys"
    );
    assert.deepEqual(
      friendlyEntryMessages({ __failureDetails: details.toReversed() }).map(
        ({ id }) => id
      ),
      result.map(({ id }) => id).toReversed(),
      "keys follow each instruction when validation order changes"
    );
  });

  test("custom field diagnostics keep distinct block messages independently keyed", function (assert) {
    const messages = ["Choose a destination.", "Choose a treatment."];
    const entry = {
      __failureDetails: messages.map((message) => ({
        code: ERROR_CODES.CONSTRAINT_VIOLATION,
        expected: { custom: true },
        message,
      })),
    };
    const result = friendlyEntryMessages(entry);

    assert.deepEqual(
      result.map(({ text }) => text),
      messages,
      "each custom message remains visible"
    );
    assert.strictEqual(
      new Set(result.map(({ id }) => id)).size,
      2,
      "different block-level issues cannot collide in a keyed list"
    );
    assert.deepEqual(
      friendlyEntryMessages({
        __failureDetails: entry.__failureDetails.toReversed(),
      }).map(({ id }) => id),
      result.map(({ id }) => id).toReversed(),
      "keys follow the diagnostic rather than its position"
    );
  });

  test("custom field diagnostics preserve the validator's translated message", function (assert) {
    assert.strictEqual(
      friendlyErrorMessage({
        code: ERROR_CODES.CONSTRAINT_VIOLATION,
        field: "imageAlt",
        expected: { custom: true },
        message: "Describe this informative image.",
      }),
      "Describe this informative image.",
      "custom completeness instructions are not replaced by a generic constraint message"
    );
  });

  test("an unknown entry key is stamped with a structured code", async function (assert) {
    const entry = { block: LeafBlock, bogusKey: {} };
    await validatePermissively(getOwner(this), entry);

    const codes = (entry.__failureDetails ?? []).map((d) => d.code);
    assert.true(
      codes.includes(ERROR_CODES.UNKNOWN_ENTRY_KEY),
      "the unknown key is stamped as a structured detail"
    );
  });

  test("an unknown entry key surfaces a friendly message, not the raw [Blocks] reason", async function (assert) {
    const entry = { block: LeafBlock, bogusKey: {} };
    await validatePermissively(getOwner(this), entry);

    const messages = friendlyEntryMessages(entry);
    assert.strictEqual(messages.length, 1, "one message");
    assert.false(
      messages[0].text.startsWith("[Blocks]"),
      "the raw developer string does not leak through"
    );
    assert.false(
      messages[0].text.includes("Context:"),
      "the error-context dump does not leak through"
    );
    assert.true(
      messages[0].text.includes("bogusKey"),
      "the offending key is named"
    );
  });

  test("a composite overrides key is accepted, not flagged as unknown", async function (assert) {
    const entry = { block: LeafBlock, overrides: { title: { text: "Hi" } } };
    await validatePermissively(getOwner(this), entry);

    assert.strictEqual(
      entry.__failureDetails,
      undefined,
      "overrides is a valid entry key, so no failure is stamped"
    );
  });

  test("a wrong entry field type surfaces a friendly message", async function (assert) {
    const entry = { block: LeafBlock, children: "not-an-array" };
    await validatePermissively(getOwner(this), entry);

    const codes = (entry.__failureDetails ?? []).map((d) => d.code);
    assert.true(
      codes.includes(ERROR_CODES.INVALID_ENTRY_TYPE),
      "the bad field type is stamped as a structured detail"
    );

    const messages = friendlyEntryMessages(entry);
    assert.false(
      messages[0].text.startsWith("[Blocks]"),
      "the raw developer string does not leak through"
    );
  });

  test("an invalid entry id surfaces a friendly message", async function (assert) {
    const entry = { block: LeafBlock, id: "Not Valid" };
    await validatePermissively(getOwner(this), entry);

    const codes = (entry.__failureDetails ?? []).map((d) => d.code);
    assert.true(
      codes.includes(ERROR_CODES.INVALID_ENTRY_ID),
      "the bad id is stamped as a structured detail"
    );

    const messages = friendlyEntryMessages(entry);
    assert.false(
      messages[0].text.startsWith("[Blocks]"),
      "the raw developer string does not leak through"
    );
  });

  test("friendlyErrorMessage maps the structural entry codes to i18n", function (assert) {
    assert.strictEqual(
      friendlyErrorMessage({
        code: ERROR_CODES.UNKNOWN_ENTRY_KEY,
        expected: { keys: ["bogusKey"] },
      }),
      'Unknown block key(s): "bogusKey".',
      "unknown-entry-key maps to a friendly, key-naming message"
    );
  });
});
