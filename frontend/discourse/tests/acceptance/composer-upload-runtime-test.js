import { getOwner } from "@ember/owner";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { getUppy, resetUppyForTesting } from "discourse/lib/load-uppy";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Upload runtime", function (needs) {
  needs.user();

  test("the editor mounts once the upload runtime has loaded", async function (assert) {
    await visit("/t/internationalization-localization/280");
    resetUppyForTesting();

    let loadedAtMount;
    getOwner(this)
      .lookup("service:app-events")
      .one("composer:will-open", () => {
        try {
          getUppy();
          loadedAtMount = true;
        } catch {
          loadedAtMount = false;
        }
      });

    await click("#topic-footer-buttons .create");

    assert.dom(".d-editor-input").exists("the composer opens");
    assert.true(
      loadedAtMount,
      "theme hooks on the editor can use the uploader as soon as it mounts"
    );
  });
});
