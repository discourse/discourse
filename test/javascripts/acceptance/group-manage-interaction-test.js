import { acceptance, updateCurrentUser } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";
import groupFixtures from "fixtures/group-fixtures";

acceptance("Managing Group Interaction Settings", {
  loggedIn: true,
  settings: {
    email_in: true
  }
});

QUnit.test("As an admin", async assert => {
  updateCurrentUser({
    moderator: false,
    admin: true,
    can_create_group: true
  });

  let groupResponse = _.clone(groupFixtures["/groups/discourse.json"]);
  groupResponse.group.can_admin_group = true;
  pretender.get("/groups/discourse.json", () => [
    200,
    { "Content-Type": "application/json" },
    groupResponse
  ]);

  await visit("/g/discourse/manage/interaction");

  assert.equal(
    find(".groups-form-visibility-level").length,
    1,
    "it should display visibility level selector"
  );

  assert.equal(
    find(".groups-form-mentionable-level").length,
    1,
    "it should display mentionable level selector"
  );

  assert.equal(
    find(".groups-form-messageable-level").length,
    1,
    "it should display messageable level selector"
  );

  assert.equal(
    find(".groups-form-incoming-email").length,
    1,
    "it should display incoming email input"
  );

  assert.equal(
    find(".groups-form-default-notification-level").length,
    1,
    "it should display default notification level input"
  );
});

QUnit.test("As a group owner", async assert => {
  updateCurrentUser({
    moderator: false,
    admin: false,
    can_create_group: false
  });

  let groupResponse = _.clone(groupFixtures["/groups/discourse.json"]);
  groupResponse.group.can_admin_group = false;
  pretender.get("/groups/discourse.json", () => [
    200,
    { "Content-Type": "application/json" },
    groupResponse
  ]);

  await visit("/g/discourse/manage/interaction");

  assert.equal(
    find(".groups-form-visibility-level").length,
    0,
    "it should not display visibility level selector"
  );

  assert.equal(
    find(".groups-form-mentionable-level").length,
    1,
    "it should display mentionable level selector"
  );

  assert.equal(
    find(".groups-form-messageable-level").length,
    1,
    "it should display messageable level selector"
  );

  assert.equal(
    find(".groups-form-incoming-email").length,
    0,
    "it should not display incoming email input"
  );

  assert.equal(
    find(".groups-form-default-notification-level").length,
    1,
    "it should display default notification level input"
  );
});
