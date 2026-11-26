import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { ADD_TRANSLATION, EDIT } from "discourse/models/composer";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | post-image-caption-editor", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.composer = this.owner.lookup("service:composer");
    const site = this.owner.lookup("service:site");
    this.composer.model = {
      action: EDIT,
      locale: "ja",
      post: { id: 42, post_type: site.post_types.regular },
    };

    this.settings = this.owner.lookup("service:site-settings");
    this.settings.discourse_ai_enabled = true;
    this.settings.ai_post_image_captions_enabled = true;
    this.editor = this.owner.lookup("service:post-image-caption-editor");
  });

  test("load uses the edited post's locale", async function (assert) {
    pretender.get("/discourse-ai/post-image-captions/42", (request) => {
      assert.strictEqual(
        request.queryParams.locale,
        "ja",
        "uses the edited locale"
      );
      return response({ captions: [] });
    });

    await this.editor.load(this.editor.captureContext());
  });

  test("load and save use the selected translation locale", async function (assert) {
    this.composer.model.action = ADD_TRANSLATION;
    this.composer.selectedTranslationLocale = "fr";
    pretender.get("/discourse-ai/post-image-captions/42", (request) => {
      assert.strictEqual(
        request.queryParams.locale,
        "fr",
        "loads the French caption"
      );
      return response({ captions: [] });
    });
    pretender.put("/discourse-ai/post-image-captions/42/abc123", (request) => {
      const params = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        params.get("locale"),
        "fr",
        "saves the French caption"
      );
      assert.strictEqual(
        params.get("description"),
        "La description",
        "sends the edited description"
      );
      return response({ base62_sha1: "abc123", description: "La description" });
    });

    const context = this.editor.captureContext();
    await this.editor.load(context);
    await this.editor.save(context, "abc123", "La description");
  });

  test("both settings are required for the plugin control", function (assert) {
    assert.true(this.editor.enabled, "both settings enable the control");
    this.settings.discourse_ai_enabled = false;
    assert.false(
      this.editor.enabled,
      "the global setting overrides the caption setting"
    );
    this.settings.discourse_ai_enabled = true;
    this.settings.ai_post_image_captions_enabled = false;
    assert.false(this.editor.enabled, "the caption setting is also required");
  });

  test("private messages and ineligible posts cannot edit captions", function (assert) {
    this.composer.model.privateMessage = true;
    assert.false(this.editor.enabled, "private messages use the core control");

    this.composer.model.privateMessage = false;
    this.composer.model.post.deleted_at = "2026-01-01";
    assert.false(
      this.editor.captureContext().canEditCaption,
      "deleted posts cannot edit captions"
    );

    this.composer.model.post.deleted_at = null;
    this.composer.model.action = "reply";
    assert.false(
      this.editor.captureContext().canEditCaption,
      "new replies cannot edit captions"
    );
  });
});
