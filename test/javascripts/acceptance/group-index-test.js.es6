import { acceptance, logIn, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Group Members");

QUnit.test("Viewing Members as anon user", async assert => {
  await visit("/groups/discourse");

  assert.ok(
    count(".avatar-flair .d-icon-adjust") === 1,
    "it displays the group's avatar flair"
  );
  assert.ok(count(".group-members tr") > 0, "it lists group members");

  assert.ok(
    count(".group-member-dropdown") === 0,
    "it does not allow anon user to manage group members"
  );

  assert.equal(
    find(".group-username-filter").attr("placeholder"),
    I18n.t("groups.members.filter_placeholder"),
    "it should display the right filter placehodler"
  );
});

QUnit.test("Viewing Members as a group owner", async assert => {
  logIn();
  Discourse.reset();
  replaceCurrentUser({ admin: false, staff: false });

  await visit("/groups/discourse");
  await click(".group-members-add");

  assert.equal(
    find("#group-add-members-user-selector").length,
    1,
    "it should display the add members modal"
  );
});

QUnit.test("Viewing Members as an admin user", async assert => {
  logIn();
  Discourse.reset();

  await visit("/groups/discourse");

  assert.ok(
    count(".group-member-dropdown") > 0,
    "it allows admin user to manage group members"
  );

  assert.equal(
    find(".group-username-filter").attr("placeholder"),
    I18n.t("groups.members.filter_placeholder_admin"),
    "it should display the right filter placehodler"
  );
});
