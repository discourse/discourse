import {
  click,
  currentURL,
  fillIn,
  select,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance, createFile } from "discourse/tests/helpers/qunit-helpers";

const emojiList = [
  {
    name: "partyblob",
    url: "/images/emoji/twitter/partyblob.png",
    group: "fun",
    created_by: "admin",
  },
  {
    name: "wave",
    url: "/images/emoji/twitter/wave.png",
    group: "default",
    created_by: "admin",
  },
];

const previewResponse = {
  token: "abc123",
  rows: [
    {
      index: 0,
      name: "new-emoji",
      group: "default",
      filename: "new-emoji.png",
      category: "new",
      incoming_url: "/images/emoji/twitter/new-emoji.png",
      existing_url: null,
    },
    {
      index: 1,
      name: "partyblob",
      group: "fun",
      filename: "partyblob.png",
      category: "identical",
      incoming_url: "/images/emoji/twitter/partyblob.png",
      existing_url: "/images/emoji/twitter/partyblob.png",
    },
    {
      index: 2,
      name: "wave",
      group: "reactions",
      filename: "wave.png",
      category: "conflict_group",
      incoming_url: "/images/emoji/twitter/wave.png",
      existing_url: "/images/emoji/twitter/wave.png",
    },
    {
      index: 3,
      name: "bad-emoji",
      group: "default",
      filename: "bad-emoji.bmp",
      category: "invalid",
      errors: ["File extension .bmp is not supported"],
    },
  ],
};

acceptance("Admin - Emoji", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/config/emoji.json", () => helper.response(emojiList));
    server.get("/admin/config/emoji/settings", () => helper.response({}));
    server.delete("/admin/config/emoji/:name", () => helper.response({}));
    server.post("/admin/config/emoji/import_preview", () =>
      helper.response(previewResponse)
    );
    server.post("/admin/config/emoji/import_confirm", () =>
      helper.response({ created: 1, updated: 1, skipped: 1 })
    );
  });

  // ─── List ──────────────────────────────────────────────────────────────────

  test("lists custom emojis with a delete button per row and a select-to-export button", async function (assert) {
    await visit("/admin/config/emoji");

    assert
      .dom(".admin-emoji-list tbody .d-table__row")
      .exists({ count: 2 }, "renders one row per emoji");

    assert
      .dom(".admin-emoji-list__select-to-export")
      .exists("select-to-export button is shown");

    assert
      .dom(".admin-emoji-list tbody .d-table__cell-action-delete")
      .exists({ count: 2 }, "each row has a delete button");

    assert
      .dom(".admin-emoji-list__select")
      .doesNotExist("checkboxes not shown before selecting mode");
  });

  test("filters custom emojis by name", async function (assert) {
    await visit("/admin/config/emoji");

    await fillIn(".filter-input", "party");

    assert
      .dom(".admin-emoji-list tbody .d-table__row")
      .exists({ count: 1 }, "only the emoji matching by name is shown");
    assert
      .dom(".admin-emoji-list tbody")
      .containsText(":partyblob:", "shows the matching emoji");
  });

  test("filters custom emojis by group", async function (assert) {
    await visit("/admin/config/emoji");

    await select(".d-filter-controls__dropdown", "fun");

    assert
      .dom(".admin-emoji-list tbody .d-table__row")
      .exists({ count: 1 }, "only emojis in the selected group are shown");
    assert
      .dom(".admin-emoji-list tbody")
      .containsText(":partyblob:", "shows the emoji in the selected group");
  });

  // ─── Select to export flow ─────────────────────────────────────────────────

  test("clicking select-to-export enters selecting mode and shows checkboxes", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji-list__select-to-export");

    assert
      .dom(".admin-emoji-list__select")
      .exists({ count: 2 }, "per-row checkboxes shown in selecting mode");

    assert
      .dom(".admin-emoji-list__select-all")
      .exists("select-all checkbox shown in selecting mode");

    assert
      .dom(".admin-emoji-list__export-btn")
      .exists("export button shown in selecting mode");

    assert
      .dom(".admin-emoji-list__cancel-btn")
      .exists("cancel button shown in selecting mode");

    assert
      .dom(".admin-emoji-list__select-to-export")
      .doesNotExist("select-to-export button hidden in selecting mode");
  });

  test("navigating away from the emoji list clears selecting mode", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji-list__select-to-export");
    assert
      .dom(".admin-emoji-list__select")
      .exists("checkboxes shown in selecting mode");

    await click(".admin-emoji__import");

    await visit("/admin/config/emoji");
    assert
      .dom(".admin-emoji-list__select")
      .doesNotExist("selecting mode cleared after navigating away and back");

    assert
      .dom(".admin-emoji-list__select-to-export")
      .exists("select-to-export button visible again");
  });

  test("cancel exits selecting mode and hides checkboxes", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji-list__select-to-export");
    await click(".admin-emoji-list__cancel-btn");

    assert
      .dom(".admin-emoji-list__select")
      .doesNotExist("checkboxes hidden after cancel");

    assert
      .dom(".admin-emoji-list__select-to-export")
      .exists("select-to-export button visible again after cancel");
  });

  test("select-all checks all rows and deselect-all unchecks them", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji-list__select-to-export");

    await click(".admin-emoji-list__select-all");
    assert
      .dom(".admin-emoji-list__select:checked")
      .exists({ count: 2 }, "all rows selected after select-all");

    await click(".admin-emoji-list__select-all");
    assert
      .dom(".admin-emoji-list__select:checked")
      .doesNotExist("all rows deselected after clicking select-all again");
  });

  test("select-all only selects emojis visible through the filters", async function (assert) {
    await visit("/admin/config/emoji");

    await fillIn(".filter-input", "party");
    await click(".admin-emoji-list__select-to-export");
    await click(".admin-emoji-list__select-all");
    await fillIn(".filter-input", "");

    assert
      .dom(".admin-emoji-list__select:checked")
      .exists({ count: 1 }, "only the filtered emoji is selected");
  });

  test("selecting a row makes header select-all indeterminate", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji-list__select-to-export");

    await click(
      ".admin-emoji-list tbody .d-table__row:first-child .admin-emoji-list__select"
    );

    assert
      .dom(".admin-emoji-list__select-all")
      .hasProperty("indeterminate", true, "header checkbox is indeterminate");
  });

  test("export button is present in page header", async function (assert) {
    await visit("/admin/config/emoji");

    assert.dom(".admin-emoji__import").exists("import button is present");
  });

  // ─── Import navigation ─────────────────────────────────────────────────────

  test("import button navigates to the import route", async function (assert) {
    await visit("/admin/config/emoji");

    await click(".admin-emoji__import");

    assert
      .dom(".admin-emoji-import__file-input")
      .exists("navigates to import page");
  });

  test("import page shows file picker initially", async function (assert) {
    await visit("/admin/config/emoji/import");

    assert
      .dom(".admin-emoji-import__file-input")
      .exists("file input is shown on import page");
  });

  // ─── Import preview ────────────────────────────────────────────────────────

  test("uploading a ZIP shows the confirmation view with categorised rows", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__summary")
      .exists("summary bar is shown after upload");

    assert
      .dom(".admin-emoji-import__actions .btn-primary")
      .exists("confirm import button is shown");

    assert
      .dom(".admin-emoji-import__actions .btn-default")
      .exists("cancel button is shown");
  });

  test("summary bar shows correct counts", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__summary")
      .hasText(
        "1 new · 1 conflicts · 1 unchanged · 1 errors",
        "summary shows correct counts"
      );
  });

  test("invalid rows count appears in summary", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__summary")
      .containsText("1 errors", "invalid count shown in summary");
  });

  test("confirming the import navigates back to the emoji list", async function (assert) {
    let confirmCalled = false;
    pretender.post("/admin/config/emoji/import_confirm", () => {
      confirmCalled = true;
      return response({});
    });

    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    await click(".admin-emoji-import__actions .btn-primary");

    assert.true(confirmCalled, "confirm endpoint was called");

    assert.strictEqual(
      currentURL(),
      "/admin/config/emoji",
      "navigates back to emoji list after confirm"
    );
  });

  test("cancel from confirmation view returns to file picker", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    await click(".admin-emoji-import__actions .btn-default");

    assert
      .dom(".admin-emoji-import__file-input")
      .exists("back to file picker after cancel");
  });

  test("preview renders a section for each category with rows", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__section")
      .exists(
        { count: 3 },
        "three sections rendered (new/identical, conflict, invalid)"
      );

    assert
      .dom(".admin-emoji-import__table")
      .exists({ count: 3 }, "each section has a table");

    assert
      .dom(".admin-emoji-import__table .d-table__row")
      .exists("at least one row is rendered in the tables");
  });

  test("new emoji section shows incoming image", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__table img.emoji-custom")
      .exists("incoming emoji images are shown in the preview tables");
  });

  test("conflict section shows resolution radio buttons", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__conflict-resolution")
      .exists("conflict resolution controls are shown");

    assert
      .dom(".admin-emoji-import__conflict-resolution input[type='radio']")
      .exists({ count: 2 }, "two radio options (incoming / keep existing)");
  });

  test("invalid section shows error message", async function (assert) {
    await visit("/admin/config/emoji/import");

    const file = createFile("emojis.zip", "application/zip");
    await triggerEvent(".admin-emoji-import__file-input", "change", {
      files: [file],
    });

    assert
      .dom(".admin-emoji-import__error")
      .exists("error message shown for invalid row");

    assert
      .dom(".admin-emoji-import__error")
      .hasText(
        "File extension .bmp is not supported",
        "error text matches the validation message"
      );
  });
});
