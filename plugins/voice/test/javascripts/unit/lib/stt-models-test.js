import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  DEFAULT_STT_MODEL,
  preferredSttModel,
  setPreferredSttModel,
  STT_MODELS,
  sttModelUrl,
} from "discourse/plugins/voice/discourse/lib/voice/stt-models";

module("Voice | Unit | Lib | stt-models", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    localStorage.removeItem("voice:stt-model");
  });

  hooks.afterEach(function () {
    localStorage.removeItem("voice:stt-model");
  });

  test("defaults to the best-quality model", function (assert) {
    assert.strictEqual(DEFAULT_STT_MODEL, "ultra");
    assert.strictEqual(preferredSttModel(), "ultra");
  });

  test("remembers a chosen model and ignores unknown ones", function (assert) {
    setPreferredSttModel("redux");
    assert.strictEqual(preferredSttModel(), "redux");

    setPreferredSttModel("v3");
    assert.strictEqual(
      preferredSttModel(),
      "redux",
      "unknown ids aren't stored"
    );

    localStorage.setItem("voice:stt-model", "v3");
    assert.strictEqual(
      preferredSttModel(),
      "ultra",
      "a stale stored id falls back to the default"
    );
  });

  test("model URLs are folders under the pinned repository or a mirror", function (assert) {
    assert.true(
      /^https:\/\/huggingface\.co\/Discourse\/Discourse-STT\/resolve\/[0-9a-f]{40}\/ultra-q4$/.test(
        sttModelUrl("ultra")
      ),
      "the default root is pinned to a commit"
    );
    assert.strictEqual(
      sttModelUrl("redux", "https://cdn.example.com/stt/"),
      "https://cdn.example.com/stt/redux-w2a8"
    );
    assert.deepEqual(Object.keys(STT_MODELS), ["ultra", "redux"]);
  });
});
