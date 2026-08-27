import { module, test } from "qunit";
import {
  capabilities,
  resetKeyboardEvidence,
} from "discourse/services/capabilities";

module("Unit | Service | capabilities | keyboard evidence", function () {
  test("gate: a keydown is remembered as evidence until reset", function (assert) {
    resetKeyboardEvidence();
    assert.false(capabilities.hasKeyboardEvidence, "starts without evidence");

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab" }));
    assert.true(capabilities.hasKeyboardEvidence, "a Tab press is evidence");

    resetKeyboardEvidence();
    assert.false(capabilities.hasKeyboardEvidence, "reset clears it");
  });

  test("gate: evidence from an earlier test does not leak into this one", function (assert) {
    assert.false(capabilities.hasKeyboardEvidence);
  });
});
