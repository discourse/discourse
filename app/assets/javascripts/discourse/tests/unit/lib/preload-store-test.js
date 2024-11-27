import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { Promise } from "rsvp";
import PreloadStore from "discourse/lib/preload-store";

module("Unit | Utility | preload-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    PreloadStore.store("bane", "evil");
  });

  test("get", function (assert) {
    assert.blank(PreloadStore.get("joker"), "returns blank for a missing key");
    assert.strictEqual(
      PreloadStore.get("bane"),
      "evil",
      "returns the value for that key"
    );
  });

  test("remove", function (assert) {
    PreloadStore.remove("bane");
    assert.blank(
      PreloadStore.get("bane"),
      "removes the value if the key exists"
    );
  });

  test("getAndRemove returns a promise that resolves to null", async function (assert) {
    assert.blank(await PreloadStore.getAndRemove("joker"));
  });

  test("getAndRemove returns a promise that resolves to the result of the finder", async function (assert) {
    const finder = () => "batdance";
    const result = await PreloadStore.getAndRemove("joker", finder);

    assert.strictEqual(result, "batdance");
  });

  test("getAndRemove returns a promise that resolves to the result of the finder's promise", async function (assert) {
    const finder = async () => "hahahah";
    const result = await PreloadStore.getAndRemove("joker", finder);

    assert.strictEqual(result, "hahahah");
  });

  test("returns a promise that rejects with the result of the finder's rejected promise", async function (assert) {
    const finder = () => Promise.reject("error");

    await PreloadStore.getAndRemove("joker", finder).catch((result) => {
      assert.strictEqual(result, "error");
    });
  });

  test("returns a promise that resolves to 'evil'", async function (assert) {
    const result = await PreloadStore.getAndRemove("bane");
    assert.strictEqual(result, "evil");
  });

  test("returns falsy values without calling finder", async function (assert) {
    PreloadStore.store("falsy", false);
    const result = await PreloadStore.getAndRemove("falsy", () =>
      assert.ok(false)
    );
    assert.false(result);
  });
});
