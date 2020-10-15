import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Tag Groups", {
  loggedIn: true,
  settings: { tagging_enabled: true },
  pretend(server, helper) {
    server.post("/tag_groups", () => {
      return helper.response({
        tag_group: {
          id: 42,
          name: "test tag group",
          tag_names: ["monkey"],
          parent_tag_name: [],
          one_per_topic: false,
          permissions: { everyone: 1 },
        },
      });
    });

    server.get("/groups/search.json", () => {
      return helper.response([
        {
          id: 88,
          name: "tl1",
        },
        {
          id: 89,
          name: "tl2",
        },
      ]);
    });
  },
});

test("tag groups can be saved and deleted", async (assert) => {
  const tags = selectKit(".tag-chooser");

  await visit("/tag_groups");
  await click(".content-list .btn");

  await fillIn(".tag-group-content h1 input", "test tag group");
  await tags.expand();
  await tags.selectRowByValue("monkey");

  await click(".tag-group-content .btn.btn-default");

  await click(".tag-chooser .choice:first");
  assert.ok(!find(".tag-group-content .btn.btn-danger")[0].disabled);
});

QUnit.test(
  "tag groups can have multiple groups added to them",
  async (assert) => {
    const tags = selectKit(".tag-chooser");
    const groups = selectKit(".group-chooser");

    await visit("/tag_groups");
    await click(".content-list .btn");

    await fillIn(".tag-group-content h1 input", "test tag group");
    await tags.expand();
    await tags.selectRowByValue("monkey");

    await click("#private-permission");
    assert.ok(find(".tag-group-content .btn.btn-default:disabled").length);

    await groups.expand();
    await groups.selectRowByIndex(1);
    await groups.selectRowByIndex(0);
    assert.ok(!find(".tag-group-content .btn.btn-default")[0].disabled);
  }
);
