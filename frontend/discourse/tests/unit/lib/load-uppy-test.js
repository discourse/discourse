import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import loadUppy, { getUppy, withUppy } from "discourse/lib/load-uppy";

module("Unit | Lib | load-uppy", function (hooks) {
  setupTest(hooks);

  test("concurrent and repeated loads share the runtime", async function (assert) {
    const firstLoad = loadUppy();
    const secondLoad = loadUppy();
    assert.strictEqual(
      firstLoad,
      secondLoad,
      "concurrent loads share one tracked promise"
    );
    const [first, second] = await Promise.all([firstLoad, secondLoad]);
    assert.strictEqual(first, second, "concurrent consumers share the runtime");
    assert.strictEqual(
      await loadUppy(),
      first,
      "later consumers reuse the runtime"
    );
    assert.strictEqual(
      getUppy(),
      first,
      "synchronous setup can access the runtime"
    );
    let ranWith;
    withUppy((runtime) => (ranWith = runtime));
    assert.strictEqual(
      ranWith,
      first,
      "a loaded runtime is used synchronously"
    );
    assert.strictEqual(
      typeof first.Uppy,
      "function",
      "the uploader constructor is available"
    );
  });
});
