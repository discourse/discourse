import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Site from "discourse/models/site";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("New Group - Anonymous", function () {
  test("As an anon user", async function (assert) {
    await visit("/g");

    assert
      .dom(".groups-header-new")
      .doesNotExist("it should not display the button to create a group");
  });
});

acceptance("New Group - Authenticated", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/admin/groups", () => {
      return helper.response(200, {
        basic_group: {
          id: 99,
          automatic: false,
          name: "site-moderators",
          full_name: "Site Moderators",
          user_count: 0,
          flair_url: "/uploads/default/flair.png",
          flair_bg_color: "ff0000",
          flair_color: "ffffff",
        },
      });
    });
    server.get("/groups/site-moderators.json", () => {
      return helper.response(200, {
        group: {
          id: 99,
          name: "site-moderators",
          automatic: false,
          user_count: 0,
        },
        extras: { visible_group_names: ["site-moderators"] },
      });
    });
    server.get("/groups/site-moderators/members.json", () => {
      return helper.response(200, {
        members: [],
        meta: { total: 0, limit: 50, offset: 0 },
      });
    });
  });

  test("Creating a new group", async function (assert) {
    await visit("/g");
    await click(".groups-header-new");

    assert.dom(".group-form-save").isDisabled("save button is disabled");

    await fillIn("input[name='name']", "1");

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.too_short"),
        "it should show the right validation tooltip"
      );

    assert.dom(".group-form-save").isDisabled("disables the save button");

    await fillIn(
      "input[name='name']",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    );

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.too_long"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "");

    assert
      .dom(".tip.bad")
      .hasText(
        i18n("admin.groups.new.name.blank"),
        "it should show the right validation tooltip"
      );

    await fillIn("input[name='name']", "site-moderators");

    assert
      .dom(".tip.good")
      .hasText(
        i18n("admin.groups.new.name.available"),
        "it should show the right validation tooltip"
      );

    await click(".group-form-public-admission");

    assert
      .dom("groups-new-allow-membership-requests")
      .doesNotExist("it should disable the membership requests checkbox");

    assert
      .dom(".groups-form-default-notification-level .selected-name .name")
      .hasText(
        i18n("groups.notifications.watching.title"),
        "has a default selection for notification level"
      );
  });

  test("Creating a group adds it to site groups", async function (assert) {
    const initialGroupCount = Site.current().groups.length;

    await visit("/g/custom/new");
    await fillIn("input[name='name']", "site-moderators");
    await click(".group-form-save");

    assert.strictEqual(
      Site.current().groups.length,
      initialGroupCount + 1,
      "site.groups has the new group"
    );

    const newGroup = Site.current().groups.find(
      (g) => g.name === "site-moderators"
    );
    assert.deepEqual(
      newGroup,
      {
        id: 99,
        name: "site-moderators",
        full_name: "Site Moderators",
        display_name: "Site Moderators",
        flair_url: "/uploads/default/flair.png",
        flair_bg_color: "ff0000",
        flair_color: "ffffff",
        automatic: false,
      },
      "the new group has the keys the server sends for site groups"
    );
  });

  test("Creating a group without a full name names it after the group", async function (assert) {
    pretender.post("/admin/groups", () =>
      response(200, {
        basic_group: {
          id: 99,
          automatic: false,
          name: "site-moderators",
          full_name: null,
          flair_url: null,
          flair_bg_color: null,
          flair_color: null,
        },
      })
    );

    await visit("/g/custom/new");
    await fillIn("input[name='name']", "site-moderators");
    await click(".group-form-save");

    const newGroup = Site.current().groups.find(
      (g) => g.name === "site-moderators"
    );
    assert.strictEqual(newGroup.full_name, "site-moderators");
    assert.strictEqual(newGroup.display_name, "site-moderators");
    assert.strictEqual(newGroup.flair_url, null);
  });
});
