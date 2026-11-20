import { module, test } from "qunit";
import {
  DEFAULT_MAX_FILE_SIZE,
  fileTransferMaxSize,
  MEBIBYTE,
} from "discourse/plugins/live/discourse/lib/live/file-transfer-limits";

module("Live | Unit | Lib | file-transfer-limits", function () {
  test("converts valid settings from MiB to safe bytes", function (assert) {
    for (const value of [1, 100, 256, 102400]) {
      assert.strictEqual(
        fileTransferMaxSize(value),
        value * MEBIBYTE,
        `converts ${value} MiB`
      );
    }
  });

  test("invalid settings use the safe default", function (assert) {
    for (const value of [
      undefined,
      null,
      "256",
      NaN,
      Infinity,
      0,
      -1,
      1.5,
      102401,
      Number.MAX_SAFE_INTEGER,
    ]) {
      assert.strictEqual(
        fileTransferMaxSize(value),
        DEFAULT_MAX_FILE_SIZE,
        `safe default for ${value}`
      );
    }
  });
});
