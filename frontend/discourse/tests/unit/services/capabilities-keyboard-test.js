import { module, test } from "qunit";
import {
  capabilities,
  noteKeyboardEvidence,
  resetKeyboardEvidence,
} from "discourse/services/capabilities";

module("Unit | Service | capabilities | keyboard evidence", function () {
  test("gate: a keydown is remembered as evidence until reset", function (assert) {
    resetKeyboardEvidence();
    assert.false(capabilities.hasKeyboardEvidence, "reset clears it");

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab" }));
    assert.true(capabilities.hasKeyboardEvidence, "a Tab press is evidence");

    resetKeyboardEvidence();
    noteKeyboardEvidence();
    assert.true(capabilities.hasKeyboardEvidence, "noted directly");
  });

  test("gate: every test starts with a keyboard assumed present", function (assert) {
    // The previous test may have reset the evidence; each test starts fresh
    // with it set, so shortcut rendering is deterministic regardless of the
    // browser's pointer.
    assert.true(capabilities.hasKeyboardEvidence);
  });
});
