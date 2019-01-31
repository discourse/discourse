import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - User Index", { loggedIn: true });

QUnit.test("can edit username", async assert => {
  /* global server */
  server.put("/users/sam/preferences/username", () => [
    200,
    { "Content-Type": "application/json" },
    { id: 2, username: "new-sam" }
  ]);

  await visit("/admin/users/2/sam");

  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "sam"
  );

  // Trying cancel.
  await click(".display-row.username button");
  await fillIn(".display-row.username .value input", "new-sam");
  await click(".display-row.username a");
  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "sam"
  );

  // Doing edit.
  await click(".display-row.username button");
  await fillIn(".display-row.username .value input", "new-sam");
  await click(".display-row.username button");
  assert.equal(
    find(".display-row.username .value")
      .text()
      .trim(),
    "new-sam"
  );
});
