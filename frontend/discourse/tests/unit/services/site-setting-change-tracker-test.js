import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function stubHandle(overrides = {}) {
  return {
    setting: "title",
    value: "old",
    pendingValue: "new",
    updateExistingUsers: false,
    requiresConfirmation: false,
    affectsExistingUsers: false,
    requiresReload: false,
    isSaving: false,
    validationMessage: null,
    committed: false,
    rolledBack: false,
    commit() {
      this.committed = true;
      this.value = this.pendingValue;
    },
    rollback() {
      this.rolledBack = true;
    },
    ...overrides,
  };
}

module("Unit | Service | site-setting-change-tracker", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.tracker = getOwner(this).lookup("service:site-setting-change-tracker");
  });

  test("save sends every dirty setting in one bulk update and commits on success", async function (assert) {
    let body;
    pretender.put("/admin/site_settings/bulk_update.json", (request) => {
      body = request.requestBody;
      return response({ success: "OK" });
    });

    const title = stubHandle();
    const backfilled = stubHandle({
      setting: "default_email_digest_frequency",
      pendingValue: "10080",
      updateExistingUsers: true,
    });

    this.tracker.add(title);
    this.tracker.add(backfilled);

    await this.tracker.save();

    const params = new URLSearchParams(body);
    assert.strictEqual(params.get("settings[title][value]"), "new");
    assert.strictEqual(params.get("settings[title][backfill]"), "false");
    assert.strictEqual(
      params.get("settings[default_email_digest_frequency][value]"),
      "10080"
    );
    assert.strictEqual(
      params.get("settings[default_email_digest_frequency][backfill]"),
      "true"
    );
    assert.true(title.committed);
    assert.true(backfilled.committed);
    assert.false(title.isSaving);
    assert.strictEqual(this.tracker.count, 0);
  });

  test("a failed bulk update leaves settings dirty and uncommitted", async function (assert) {
    pretender.put("/admin/site_settings/bulk_update.json", () =>
      response(422, { errors: ["nope"] })
    );

    const title = stubHandle();
    this.tracker.add(title);

    await this.tracker.save();

    assert.false(title.committed);
    assert.false(title.isSaving);
    assert.strictEqual(this.tracker.count, 1);
  });

  test("save refreshes page state for settings that require a reload", async function (assert) {
    pretender.put("/admin/site_settings/bulk_update.json", () =>
      response({ success: "OK" })
    );
    const refreshPage = sinon.stub(this.tracker, "refreshPage");

    const font = stubHandle({
      setting: "base_font",
      pendingValue: "arial",
      requiresReload: true,
    });
    this.tracker.add(font);
    this.tracker.add(stubHandle());

    await this.tracker.save();

    assert.true(
      refreshPage.calledWith({ base_font: "arial" }),
      "refreshes with the committed value of reload-requiring settings only"
    );
  });

  test("discard rolls every dirty setting back", function (assert) {
    const title = stubHandle();
    const description = stubHandle({ setting: "site_description" });

    this.tracker.add(title);
    this.tracker.add(description);

    this.tracker.discard();

    assert.true(title.rolledBack);
    assert.true(description.rolledBack);
    assert.strictEqual(this.tracker.count, 0);
  });
});
