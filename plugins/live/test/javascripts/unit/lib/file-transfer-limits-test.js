import { module, test } from "qunit";
import {
  DEFAULT_MAX_FILE_SIZE,
  fileTransferMaxSize,
  isAuthorizedFileName,
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

  test("file names follow the sender's upload extension lists", function (assert) {
    const siteSettings = {
      authorized_extensions: "jpg|PNG",
      authorized_extensions_for_staff: "zip",
    };
    assert.true(isAuthorizedFileName("photo.jpg", false, siteSettings));
    assert.true(
      isAuthorizedFileName("photo.JPG", false, siteSettings),
      "case-insensitive"
    );
    assert.true(isAuthorizedFileName("photo.png", false, siteSettings));
    assert.false(isAuthorizedFileName("archive.zip", false, siteSettings));
    assert.true(
      isAuthorizedFileName("archive.zip", true, siteSettings),
      "staff extensions add to the user list"
    );
    assert.true(isAuthorizedFileName("photo.jpg", true, siteSettings));
    assert.false(isAuthorizedFileName("photo.jpg.exe", true, siteSettings));
    assert.false(isAuthorizedFileName("jpg", false, siteSettings));
    assert.false(isAuthorizedFileName("photo.", false, siteSettings));
    assert.true(
      isAuthorizedFileName("a".repeat(300) + ".jpg", false, siteSettings),
      "long names keep their extension"
    );
    const longExtension = "b".repeat(40);
    assert.false(
      isAuthorizedFileName("a".repeat(300) + "." + longExtension, false, {
        authorized_extensions: longExtension,
        authorized_extensions_for_staff: "",
      }),
      "checks the saved name, whose overlong extension is dropped"
    );
  });

  test("wildcards authorize any file name", function (assert) {
    assert.true(
      isAuthorizedFileName("noextension", false, {
        authorized_extensions: "*",
        authorized_extensions_for_staff: "",
      })
    );
    const staffWildcard = {
      authorized_extensions: "jpg",
      authorized_extensions_for_staff: "*",
    };
    assert.true(isAuthorizedFileName("tool.exe", true, staffWildcard));
    assert.false(isAuthorizedFileName("tool.exe", false, staffWildcard));
  });
});
