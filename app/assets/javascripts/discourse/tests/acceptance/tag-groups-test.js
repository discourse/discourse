import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Tag Groups", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
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
  });

  test("tag groups can be saved and deleted", async function (assert) {
    const tags = selectKit(".tag-chooser");

    await visit("/tag_groups");
    await click(".content-list .btn");

    await fillIn(".tag-group-content h1 input", "test tag group");
    await tags.expand();
    await tags.selectRowByValue("monkey");

    await click(".tag-group-content .btn.btn-default");

    await click(".tag-chooser .choice:nth-of-type(1)");
    assert.ok(!queryAll(".tag-group-content .btn.btn-danger")[0].disabled);
  });

  test("tag groups can have multiple groups added to them", async function (assert) {
    const tags = selectKit(".tag-chooser");
    const groups = selectKit(".group-chooser");

    await visit("/tag_groups");
    await click(".content-list .btn");

    await fillIn(".tag-group-content h1 input", "test tag group");
    await tags.expand();
    await tags.selectRowByValue("monkey");

    await click("#visible-permission");
    assert.ok(queryAll(".tag-group-content .btn.btn-default:disabled").length);

    await groups.expand();
    await groups.selectRowByIndex(1);
    await groups.selectRowByIndex(0);
    assert.ok(!queryAll(".tag-group-content .btn.btn-default")[0].disabled);

    await click(".tag-group-content .btn.btn-default");
    assert.ok(
      exists("#visible-permission:checked"),
      "selected permission does not change after saving"
    );
  });
});
