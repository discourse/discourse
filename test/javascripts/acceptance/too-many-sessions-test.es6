import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from "preload-store";

acceptance("Too many sessions warning", {
  loggedIn: true
});

QUnit.test("shows popup for too many sessions", async assert => {
  PreloadStore.store("destroyedSessions", {
    count: 3,
    limit: 100
  });

  await visit("/");
  assert.ok(exists(".bootbox.modal"), "it shows a warning");
  await click(".bootbox.modal a.btn-primary");
  assert.ok(!exists(".bootbox.modal"), "it dismisses the warning");
});
