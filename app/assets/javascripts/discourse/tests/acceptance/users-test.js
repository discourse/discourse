import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import directoryFixtures from "discourse/tests/fixtures/directory-fixtures";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

acceptance("User Directory", function () {
  test("Visit Page", async function (assert) {
    await visit("/u");
    assert.dom(document.body).hasClass("users-page", "has the body class");
    assert
      .dom(".directory .directory-table .directory-table__row")
      .exists("has a list of users");
  });

  test("Visit All Time", async function (assert) {
    await visit("/u?period=all");
    assert.dom(".time-read").exists("has time read column");
  });

  test("Visit Without Usernames", async function (assert) {
    await visit("/u?exclude_usernames=system");
    assert.dom(document.body).hasClass("users-page", "has the body class");
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

  test("Searchable user fields display as links", async function (assert) {
    pretender.get("/directory_items", () => {
      return response(cloneJSON(directoryFixtures["directory_items"]));
    });

    await visit("/u");

    assert
      .dom(
        ".directory .directory-table__body .directory-table__row:first-child .directory-table__value--user-field a"
      )
      .exists("User field is displayed as a link");

    assert
      .dom(
        ".directory .directory-table__body .directory-table__row:first-child .directory-table__value--user-field a"
      )
      .hasAttribute(
        "href",
        "/u?name=Blue&order=likes_received",
        "The link points to the correct URL"
      );

    assert
      .dom(
        ".directory .directory-table__body .directory-table__row:first-child .directory-table__value--user-field a"
      )
      .hasText("Blue", "Link text is correct");
  });

  test("Visit With Group Filter", async function (assert) {
    await visit("/u?group=trust_level_0");
    assert.dom(document.body).hasClass("users-page", "has the body class");
    assert
      .dom(".directory .directory-table .directory-table__row")
      .exists("has a list of users");
  });

  test("Custom user fields are present", async function (assert) {
    await visit("/u");

    assert
      .dom(
        ".directory .directory-table__body .directory-table__row:first-child .directory-table__value--user-field"
      )
      .hasText("Blue");
  });

  test("Can sort table via keyboard", async function (assert) {
    await visit("/u");

    const secondHeading =
      ".users-directory .directory-table__header div:nth-child(2) .header-contents";

    await triggerKeyEvent(secondHeading, "keypress", "Enter");

    assert
      .dom(`${secondHeading} .d-icon-chevron-up`)
      .exists("list has been sorted");
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
        i18n("directory.no_results.body"),
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
        i18n("directory.no_results_with_search"),
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
    assert.dom(".column-name", columns[3]).hasText("Replies Posted");
    assert.dom(".column-name", columns[4]).hasText("Topics Viewed");

    // Click on row 4 and see if they are swapped
    await click(columns[4].querySelector(".move-column-up"));

    columns = fetchColumns();
    assert.dom(".column-name", columns[3]).hasText("Topics Viewed");
    assert.dom(".column-name", columns[4]).hasText("Replies Posted");

    const moveUserFieldColumnUpBtn =
      columns[columns.length - 1].querySelector(".move-column-up");
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);

    columns = fetchColumns();
    assert.dom(".column-name", columns[4]).hasText("Favorite Color");
    assert.dom(".column-name", columns[5]).hasText("Replies Posted");

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
