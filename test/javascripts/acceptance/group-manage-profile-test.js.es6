import { acceptance, logIn, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Managing Group Profile");

QUnit.test("As an admin", async assert => {
  logIn();
  Discourse.reset();

  await visit("/groups/discourse/manage/profile");

  assert.ok(
    find(".group-flair-inputs").length === 1,
    "it should display avatar flair inputs"
  );
  assert.ok(
    find(".group-form-bio").length === 1,
    "it should display group bio input"
  );
  assert.ok(
    find(".group-form-name").length === 1,
    "it should display group name input"
  );
  assert.ok(
    find(".group-form-full-name").length === 1,
    "it should display group full name input"
  );
});

QUnit.test("As a group owner", async assert => {
  logIn();
  Discourse.reset();
  replaceCurrentUser({ staff: false, admin: false });

  await visit("/groups/discourse/manage/profile");

  assert.equal(
    find(".group-form-name").length,
    0,
    "it should not display group name input"
  );
});

QUnit.test("As an anonymous user", async assert => {
  await visit("/groups/discourse/manage/profile");

  assert.ok(
    count(".group-members tr") > 0,
    "it should redirect to members page for an anonymous user"
  );
});
