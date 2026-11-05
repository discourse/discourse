import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | staff-action-log", function (hooks) {
  setupTest(hooks);

  test("shows the scheduled duration and expiry alongside the reason", function (assert) {
    const model = getOwner(this)
      .lookup("service:store")
      .createRecord("staff-action-log", {
        created_at: "2026-10-01T12:00:00Z",
        expires_at: "2026-10-08T12:00:00Z",
        details: "Spamming",
      });

    assert.true(model.formattedDetails.includes("Spamming"));
    assert.true(
      model.formattedDetails.includes("<b>Scheduled duration:</b>  7 days")
    );
    assert.true(model.formattedDetails.includes("<b>Scheduled expiry:</b>"));

    model.set("expires_at", null);
    assert.strictEqual(model.formattedDetails, "Spamming<br/>");
  });

  test("shows indefinite restrictions without a far-future date", function (assert) {
    const model = getOwner(this)
      .lookup("service:store")
      .createRecord("staff-action-log", {
        created_at: "2026-10-01T12:00:00Z",
        expires_at: "3026-10-01T12:00:00Z",
      });

    assert.true(model.formattedDetails.includes("Indefinite"));
    assert.false(model.formattedDetails.includes("Scheduled expiry"));
  });

  test("ignores invalid expiry intervals", function (assert) {
    const model = getOwner(this)
      .lookup("service:store")
      .createRecord("staff-action-log", {
        created_at: "2026-10-01T12:00:00Z",
        expires_at: "2026-09-01T12:00:00Z",
      });

    assert.strictEqual(model.formattedDetails, "");
    model.set("expires_at", "invalid");
    assert.strictEqual(model.formattedDetails, "");
  });

  test("create", function (assert) {
    const store = getOwner(this).lookup("service:store");
    assert.true(
      !!store.createRecord("staff-action-log"),
      "can be created without arguments"
    );
  });

  test("useModalForDetails - should return true when details is > 100 characters long", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const model = store.createRecord("staff-action-log", {
      details: "a".repeat(101),
    });
    assert.true(
      model.useModalForDetails,
      "should return true when details is > 100 characters long"
    );

    model.set("details", "a".repeat(100));
    assert.false(
      model.useModalForDetails,
      "should return false when details is <= 100 characters long"
    );
  });

  test("useModalForDetails - should return true when details includes a \n", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const model = store.createRecord("staff-action-log", {
      details: "important information\nthat doesn't exceed the limit",
    });
    assert.true(
      model.useModalForDetails,
      "should return true when details includes a newline character"
    );
  });
});
