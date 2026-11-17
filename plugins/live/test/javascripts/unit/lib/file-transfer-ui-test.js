import { module, test } from "qunit";
import { safeTransferFilename } from "discourse/plugins/live/discourse/lib/live/file-transfer-ui";

module("Unit | Lib | file-transfer-ui", function () {
  test("sanitizes untrusted filenames without interpreting content", function (assert) {
    assert.strictEqual(
      safeTransferFilename("../report\u202e.html"),
      "_report_.html"
    );
    assert.strictEqual(
      safeTransferFilename("folder\\file\u0000.txt"),
      "folder_file_.txt"
    );
    assert.strictEqual(safeTransferFilename("<script>.html"), "_script_.html");
    assert.strictEqual(safeTransferFilename("..."), "download");
    assert.strictEqual(safeTransferFilename("  .  "), "download");
    assert.strictEqual(safeTransferFilename("Résumé.pdf"), "Résumé.pdf");
    assert.strictEqual(safeTransferFilename("x".repeat(300)).length, 180);
  });

  test("truncation keeps the final extension", function (assert) {
    const disguised = safeTransferFilename("a".repeat(176) + ".exe.jpg");
    assert.strictEqual(disguised.length, 180);
    assert.true(disguised.endsWith(".jpg"), "inner extension is not exposed");
    assert.strictEqual(
      safeTransferFilename("a".repeat(300) + "." + "b".repeat(40)).length,
      180,
      "overlong extensions are not kept"
    );
  });
});
