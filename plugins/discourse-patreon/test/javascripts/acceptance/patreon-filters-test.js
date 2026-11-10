import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Patreon | filters", function (needs) {
  let savedRule;

  needs.user({ admin: true });
  needs.settings({ patreon_enabled: true });

  needs.hooks.beforeEach(() => {
    savedRule = null;
  });

  needs.pretender((server, helper) => {
    server.get("/admin/plugins/discourse-patreon.json", () =>
      helper.response({
        id: "discourse-patreon",
        name: "discourse-patreon",
        about: "Test plugin",
        version: "1.0.0",
        enabled: true,
      })
    );

    server.get("/patreon/list.json", () =>
      helper.response({
        filters: {},
        rewards: {
          0: { id: "0", amount_cents: 0, title: "All patrons" },
          4: { id: "4", amount_cents: 500, title: "Bronze" },
          7: { id: "7", amount_cents: 1000, title: "Silver" },
        },
        last_sync_at: null,
      })
    );

    server.get("/groups/search.json", () =>
      helper.response([
        { id: 41, name: "patrons" },
        { id: 42, name: "supporters" },
      ])
    );

    server.post("/patreon/list.json", (request) => {
      savedRule = parsePostData(request.requestBody);
      return helper.response({});
    });
  });

  test("saving a filter sends the group picked in the new filter row", async function (assert) {
    await visit("/admin/plugins/discourse-patreon/filters");

    const groupChooser = selectKit(
      "#patreon .new-filter td:first-child .select-kit"
    );
    await groupChooser.expand();
    await groupChooser.selectRowByValue(42);

    const rewardsChooser = selectKit("#patreon .new-filter .rewards");
    await rewardsChooser.expand();
    await rewardsChooser.selectRowByValue("$5 - Bronze");

    await click("#patreon .new-filter .save");

    assert.strictEqual(
      savedRule?.group_id,
      "42",
      "sends the picked group as group_id"
    );
    assert
      .dom("#patreon tbody tr td:first-child")
      .hasText("supporters", "lists the new filter under the picked group");
  });

  test("saving a filter sends the rewards picked in the new filter row", async function (assert) {
    await visit("/admin/plugins/discourse-patreon/filters");

    const rewardsChooser = selectKit("#patreon .new-filter .rewards");
    await rewardsChooser.expand();
    await rewardsChooser.selectRowByValue("$5 - Bronze");
    if (!rewardsChooser.isExpanded()) {
      await rewardsChooser.expand();
    }
    await rewardsChooser.selectRowByValue("$10 - Silver");

    await click("#patreon .new-filter .save");

    assert.deepEqual(
      savedRule?.["rewards_ids[]"],
      ["4", "7"],
      "sends the ids of the picked rewards"
    );
    assert
      .dom("#patreon tbody tr td:nth-child(2)")
      .hasText("$5 - Bronze,$10 - Silver", "lists the picked rewards");
  });
});
