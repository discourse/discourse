import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";

acceptance("User Directory", function () {
  test("Visit Page", async function (assert) {
    await visit("/u");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });

  test("Visit All Time", async function (assert) {
    await visit("/u?period=all");
    assert.ok(exists(".time-read"), "has time read column");
  });

  test("Visit Without Usernames", async function (assert) {
    await visit("/u?exclude_usernames=system");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });

  test("Visit With Group Filter", async function (assert) {
    await visit("/u?group=trust_level_0");
    assert.ok($("body.users-page").length, "has the body class");
    assert.ok(exists(".directory table tr"), "has a list of users");
  });

  test("Custom user fields are present", async function (assert) {
    await visit("/u");

    const firstRow = query(".users-directory table tr");
    const columnData = firstRow.querySelectorAll("td");
    const favoriteColorTd = columnData[columnData.length - 1];

    assert.equal(favoriteColorTd.querySelector("span").textContent, "Blue");
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
    assert.equal(columns.length, 8);

    const checked = queryAll(
      ".edit-directory-columns-container .edit-directory-column input[type='checkbox']:checked"
    );
    assert.equal(checked.length, 7);

    const unchecked = queryAll(
      ".edit-directory-columns-container .edit-directory-column input[type='checkbox']:not(:checked)"
    );
    assert.equal(unchecked.length, 1);
  });

  const fetchColumns = function () {
    return queryAll(".edit-directory-columns-container .edit-directory-column");
  };

  test("Reordering and restoring default positions", async function (assert) {
    await visit("/u");
    await click(".open-edit-columns-btn");

    let columns;
    columns = fetchColumns();
    assert.equal(
      columns[3].querySelector(".column-name").textContent.trim(),
      "Replies Posted"
    );
    assert.equal(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Topics Viewed"
    );

    // Click on row 4 and see if they are swapped
    await click(columns[4].querySelector(".move-column-up"));

    columns = fetchColumns();
    assert.equal(
      columns[3].querySelector(".column-name").textContent.trim(),
      "Topics Viewed"
    );
    assert.equal(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Replies Posted"
    );

    const moveUserFieldColumnUpBtn = columns[columns.length - 1].querySelector(
      ".move-column-up"
    );
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);
    await click(moveUserFieldColumnUpBtn);

    columns = fetchColumns();
    assert.equal(
      columns[4].querySelector(".column-name").textContent.trim(),
      "Favorite Color"
    );
    assert.equal(
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
      "Favorite Color",
    ]);
  });
});
