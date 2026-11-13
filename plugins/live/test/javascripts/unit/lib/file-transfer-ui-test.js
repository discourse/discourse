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
});
