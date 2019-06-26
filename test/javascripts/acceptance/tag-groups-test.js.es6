import selectKit from "helpers/select-kit-helper";
import { acceptance } from "helpers/qunit-helpers";

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
          permissions: { everyone: 1 }
        }
      });
    });
  }
});

QUnit.test("tag groups can be saved and deleted", async assert => {
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
