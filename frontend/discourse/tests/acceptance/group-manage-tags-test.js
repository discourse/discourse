import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Managing Group Tag Notification Defaults", function () {
  test("As an anonymous user", async function (assert) {
    await visit("/g/discourse/manage/tags");

    assert
      .dom(".group-members .group-member")
      .exists("it should redirect to members page for an anonymous user");
  });
});

acceptance("Managing Group Tag Notification Defaults", function (needs) {
  needs.user();

  let savedGroup;

  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", () => {
      return helper.response({
        results: [
          { id: 1, name: "monkey", slug: "monkey", count: 1 },
          { id: 2, name: "gazelle", slug: "gazelle", count: 2 },
          { id: 3, name: "dog", slug: "dog", count: 3 },
          { id: 4, name: "cat", slug: "cat", count: 4 },
          { id: 5, name: "owl", slug: "owl", count: 5 },
        ],
      });
    });

    server.put("/groups/47", (request) => {
      savedGroup = new URLSearchParams(request.requestBody);
      return helper.response({ success: "OK" });
    });
  });

  needs.hooks.beforeEach(() => (savedGroup = null));

  test("As an admin", async function (assert) {
    await visit("/g/discourse/manage/tags");

    assert
      .dom(".groups-notifications-form .tag-chooser")
      .exists({ count: 5 }, "displays tag inputs");
  });

  test("As a group owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    await visit("/g/discourse/manage/tags");

    assert
      .dom(".groups-notifications-form .tag-chooser")
      .exists({ count: 5 }, "displays tag inputs");
  });

  test("saves the tags chosen for each notification level", async function (assert) {
    await visit("/g/discourse/manage/tags");

    const choices = [
      ["watching_tags", "monkey"],
      ["tracking_tags", "gazelle"],
      ["watching_first_post_tags", "dog"],
      ["regular_tags", "cat"],
      ["muted_tags", "owl"],
    ];

    for (const [index, [, tag]] of choices.entries()) {
      const chooser = selectKit(
        `.groups-notifications-form .control-group:nth-child(${index + 2} of .control-group) .tag-chooser`
      );
      await chooser.expand();
      await chooser.selectRowByName(tag);
      await chooser.collapse();
    }

    await click(".group-manage-save");

    for (const [level, tag] of choices) {
      assert.deepEqual(
        savedGroup.getAll(`group[${level}][]`),
        [tag],
        `saves the chosen tag for ${level}`
      );
    }
  });
});
