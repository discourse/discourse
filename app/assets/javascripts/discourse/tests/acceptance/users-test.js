import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import directoryFixtures from "discourse/tests/fixtures/directory-fixtures";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

acceptance("User Directory", function () {
  test("Visit Page", async function (assert) {
    await visit("/u");
    assert.ok(
      document.body.classList.contains("users-page"),
      "has the body class"
    );
    assert
      .dom(".directory .directory-table .directory-table__row")
      .exists("has a list of users");
  });

  test("Visit All Time", async function (assert) {
    await visit("/u?period=all");
    assert.ok(exists(".time-read"), "has time read column");
  });

  test("Visit Without Usernames", async function (assert) {
    await visit("/u?exclude_usernames=system");
    assert.ok(
      document.body.classList.contains("users-page"),
      "has the body class"
    );
    assert
      .dom(".directory .directory-table .directory-table__row")
      .exists("has a list of users");
  });

  test("Visit With Group Exclusion", async function (assert) {
    let queryParams;

    pretender.get("/directory_items", (request) => {
      queryParams = request.queryParams;

      return response(cloneJSON(directoryFixtures["directory_items"]));
    });

    await visit("/u?exclude_groups=trust_level_0");

    assert.strictEqual(
      queryParams.exclude_groups,
      "trust_level_0",
      "includes the right query param in the API call"
    );
  });

  test("Visit With Group Filter", async function (assert) {
    await visit("/u?group=trust_level_0");
    assert.ok(
      document.body.classList.contains("users-page"),
      "has the body class"
    );
    assert
      .dom(".directory .directory-table .directory-table__row")
      .exists("has a list of users");
  });

  test("Custom user fields are present", async function (assert) {
    await visit("/u");

    const firstRowUserField = query(
      ".directory .directory-table__body .directory-table__row:first-child .directory-table__value--user-field"
    );

    assert.strictEqual(firstRowUserField.textContent, "Blue");
  });

  test("Can sort table via keyboard", async function (assert) {
    await visit("/u");

    const secondHeading =
      ".users-directory .directory-table__header div:nth-child(2) .header-contents";

    await triggerKeyEvent(secondHeading, "keypress", "Enter");

    assert.ok(
      query(`${secondHeading} .d-icon-chevron-up`),
      "list has been sorted"
    );
  });

  test("Visit with no users", async function (assert) {
    pretender.get("/directory_items", () => {
      return response({
        directory_items: [],
        meta: {
          last_updated_at: "2024-05-13T18:42:32.000Z",
          total_rows_directory_items: 0,
        },
      });
    });
    await visit("/u");

    assert
      .dom(".empty-state-body")
      .hasText(
        I18n.t("directory.no_results.body"),
        "a JIT message is shown when there are no users"
      );
  });

  test("Visit with no search results", async function (assert) {
    pretender.get("/directory_items", () => {
      return response({
        directory_items: [],
        meta: {
          last_updated_at: "2024-05-13T18:42:32.000Z",
          total_rows_directory_items: 0,
        },
      });
    });
    await visit("/u?name=somenamethatdoesnotexist");

    assert
      .dom(".empty-state-body")
      .hasText(
        I18n.t("directory.no_results_with_search"),
        "a different JIT message is used when there are no results for the search term"
      );
  });
});

acceptance("User directory - Editing columns", function (needs) {
  needs.user({ moderator: true, admin: true });

  test("The automatic columns are checked and the user field columns are unchecked by default", async function (assert) {
    await visit("/u");
    await click(".open-edit-columns-btn");

    const columns = queryAll(
      ".edit-directory-columns-container .edit-directory-column"
    );
    assert.strictEqual(columns.length, 9);

    const checked = queryAll(
      ".edit-directory-columns-container .edit-directory-column input[type='checkbox']:checked"
    );
    assert.strictEqual(checked.length, 7);

    const unchecked = queryAll(
      ".edit-directory-columns-container .edit-directory-column input[type='checkbox']:not(:checked)"
    );
    assert.strictEqual(unchecked.length, 2);
  });

  const fetchColumns = function () {
    return queryAll(".edit-directory-columns-container .edit-directory-column");
  };

  test("Reordering and restoring default positions", async function (assert) {
    await visit("/u");
    await click(".open-edit-columns-btn");

    let columns;
    columns = fetchColumns();
    assert.strictEqual(
      columns[3].querySelector(".column-name").textContent.trim(),
      "Replies Posted"
    );
    assert.strictEqual(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Topics Viewed"
    );

    // Click on row 4 and see if they are swapped
    await click(columns[4].querySelector(".move-column-up"));

    columns = fetchColumns();
    assert.strictEqual(
      columns[3].querySelector(".column-name").textContent.trim(),
      "Topics Viewed"
    );
    assert.strictEqual(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Replies Posted"
    );

    const moveUserFieldColumnUpBtn =
      columns[columns.length - 1].querySelector(".move-column-up");
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);

    columns = fetchColumns();
    assert.strictEqual(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Favorite Color"
    );
    assert.strictEqual(
      columns[5].querySelector(".column-name").textContent.trim(),
      "Replies Posted"
    );

    // Now click restore default and check order of column names
    await click(".reset-to-default");

    let columnNames = queryAll(
      ".edit-directory-columns-container .edit-directory-column .column-name"
    ).toArray();
    columnNames = columnNames.map((el) => el.textContent.trim());
    assert.deepEqual(columnNames, [
      "Received",
      "Given",
      "Topics Created",
      "Replies Posted",
      "Topics Viewed",
      "Posts Read",
      "Days Visited",
      "[en.an_extra_field]",
      "Favorite Color",
    ]);
  });
});
