import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import getVideoAttributes from "../../lib/lazy-video-attributes";

module("Unit | Lib | lazy-video-attributes", function (hooks) {
  setupTest(hooks);

  test("extracts the playlist ID", function (assert) {
    const cooked = document.createElement("div");
    cooked.classList.add("lazy-video-container");
    cooked.dataset.videoListId = "RDkPRA0W1kECg";

    assert.strictEqual(
      getVideoAttributes(cooked).listId,
      "RDkPRA0W1kECg",
      "the playlist ID is read from the cooked markup"
    );
  });
});
