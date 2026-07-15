import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { EDIT } from "discourse/models/composer";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | post-image-caption-editor", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);
    const composer = owner.lookup("service:composer");
    composer.model = {
      action: EDIT,
      locale: "ja",
      post: { id: 42 },
    };

    owner.lookup("service:site-settings").ai_post_image_captions_enabled = true;

    const service = owner.lookup("service:post-image-caption-editor");
    service.captions = new Map();
    service.loadedKey = null;
    service.loadingKey = null;
  });

  test("ensureLoaded fetches captions for the edited post", async function (assert) {
    pretender.get("/discourse-ai/post-image-captions/:post_id", (request) => {
      assert.strictEqual(request.params.post_id, "42");
      assert.strictEqual(request.queryParams.locale, "ja");

      return response({
        captions: [
          { base62_sha1: "abc123", description: "A stored description" },
        ],
      });
    });

    const service = getOwner(this).lookup("service:post-image-caption-editor");

    await service.ensureLoaded();

    assert.strictEqual(service.captionFor("abc123"), "A stored description");
  });

  test("ensureLoaded skips non-edit composers", async function (assert) {
    let requestCount = 0;
    pretender.get("/discourse-ai/post-image-captions/:post_id", () => {
      requestCount += 1;
      return response({ captions: [] });
    });

    const composer = getOwner(this).lookup("service:composer");
    composer.model.action = "reply";

    const service = getOwner(this).lookup("service:post-image-caption-editor");

    await service.ensureLoaded();

    assert.strictEqual(requestCount, 0);
  });

  test("save updates the local caption", async function (assert) {
    pretender.put(
      "/discourse-ai/post-image-captions/:post_id/:base62_sha1",
      (request) => {
        assert.strictEqual(request.params.post_id, "42");
        assert.strictEqual(request.params.base62_sha1, "abc123");

        const params = new URLSearchParams(request.requestBody);
        assert.strictEqual(params.get("locale"), "ja");

        return response({
          base62_sha1: "abc123",
          description: "An edited description",
        });
      }
    );

    const service = getOwner(this).lookup("service:post-image-caption-editor");

    await service.save("abc123", "An edited description");

    assert.strictEqual(service.captionFor("abc123"), "An edited description");
  });
});
