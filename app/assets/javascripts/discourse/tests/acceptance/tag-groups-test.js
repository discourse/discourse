import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Tag Groups", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
    const tagGroups = {
      tag_group: {
        id: 42,
        name: "test tag group",
        tag_names: ["monkey"],
        parent_tag_name: [],
        one_per_topic: false,
        permissions: { everyone: 1 },
      },
    };
    server.post("/tag_groups", () => {
      return helper.response(tagGroups);
    });
    server.get("/forum/tag_groups", () => {
      return helper.response(tagGroups);
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
    const tags = selectKit(".group-tags-list .tag-chooser");

    await visit("/tag_groups");
    await click(".tag-group-content .btn.btn-primary");

    await fillIn(".tag-group-content .group-name input", "test tag group");

    await tags.expand();
    await tags.selectRowByValue("monkey");
    await click(".tag-group-content .btn.btn-primary");
    await click(".tag-groups-sidebar li:first-child a");

    await tags.expand();
    await tags.deselectItemByValue("monkey");
    assert.dom(".tag-group-content .btn.btn-danger").isEnabled();
  });

  test("tag groups can have multiple groups added to them", async function (assert) {
    const tags = selectKit(".tag-chooser");
    const groups = selectKit(".group-chooser");

    await visit("/tag_groups");
    await click(".tag-group-content .btn.btn-primary");

    await fillIn(".tag-group-content .group-name input", "test tag group");
    await tags.expand();
    await tags.selectRowByValue("monkey");

    await click("#visible-permission");
    await groups.expand();
    await groups.selectRowByIndex(1);
    await groups.selectRowByIndex(0);

    assert.dom(".tag-group-content .btn.btn-primary").isEnabled();

    await click(".tag-group-content .btn.btn-primary");
    await click(".tag-groups-sidebar li:first-child a");

    assert
      .dom("#visible-permission:checked")
      .exists("selected permission does not change after saving");
  });

  test("going back to tags supports subfolder", async function (assert) {
    setPrefix("/forum");

    await visit("/tag_groups");
    assert
      .dom("a.tag-groups--back")
      .hasAttribute("href", "/forum/tags", "supports subfolder");
  });
});
