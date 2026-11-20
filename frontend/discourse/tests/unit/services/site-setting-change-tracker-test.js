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

  test("removing an unavailable language confirms before saving any dirty settings", async function (assert) {
    Object.assign(this.tracker.siteSettings, {
      default_locale: "en",
      available_locales: [{ value: "en" }, { value: "fr" }, { value: "ja" }],
    });
    const confirm = sinon
      .stub(this.tracker.dialog, "confirm")
      .onFirstCall()
      .resolves(false)
      .onSecondCall()
      .resolves(true);
    let requests = 0;
    let body;
    pretender.put("/admin/site_settings/bulk_update.json", (request) => {
      requests++;
      body = new URLSearchParams(request.requestBody);
      return response({});
    });
    const locales = stubHandle({
      setting: "allowed_user_locales",
      value: "fr|removed_plugin_locale",
      pendingValue: "fr",
    });
    this.tracker.add(stubHandle());
    this.tracker.add(locales);

    await this.tracker.save();

    assert.strictEqual(requests, 0);
    assert.strictEqual(this.tracker.count, 2);
    assert.false(locales.isSaving);

    await this.tracker.save();

    assert.strictEqual(confirm.callCount, 2);
    assert.strictEqual(requests, 1);
    assert.strictEqual(
      body.get("settings[allowed_user_locales][backfill]"),
      "true"
    );
    assert.true(locales.committed);
  });

  test("adding languages keeps the implicit default and does not claim confirmation", async function (assert) {
    Object.assign(this.tracker.siteSettings, {
      default_locale: "en",
      available_locales: [{ value: "en" }, { value: "fr" }, { value: "ja" }],
    });
    const confirm = sinon.stub(this.tracker.dialog, "confirm");
    let body;
    pretender.put("/admin/site_settings/bulk_update.json", (request) => {
      body = new URLSearchParams(request.requestBody);
      return response({});
    });
    this.tracker.add(
      stubHandle({
        setting: "allowed_user_locales",
        value: "en|fr",
        pendingValue: "fr|ja",
      })
    );

    await this.tracker.save();

    assert.false(confirm.called);
    assert.strictEqual(
      body.get("settings[allowed_user_locales][backfill]"),
      "false"
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
