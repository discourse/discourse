import { fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Assign | Search - Full Page", function (needs) {
  needs.settings({ assign_enabled: true });
  needs.user({ can_assign: true });
  needs.pretender((server, helper) => {
    server.get("/u/search/users", () => {
      return helper.response({
        users: [
          {
            username: "admin",
            name: "admin",
            avatar_template: "/images/avatar.png",
          },
        ],
      });
    });
  });

  test("update in:assigned filter through advanced search ui", async function (assert) {
    const inSelector = selectKit(".search-advanced-options .select-kit#in");

    await visit("/search");

    await fillIn(".search-query", "none");
    await inSelector.expand();
    await inSelector.selectRowByValue("assigned");
    assert
      .dom(".search-query")
      .hasValue(
        "none in:assigned",
        'has updated search term to "none in:assigned"'
      );
  });

  test("update in:unassigned filter through advanced search ui", async function (assert) {
    const inSelector = selectKit(".search-advanced-options .select-kit#in");

    await visit("/search");

    await fillIn(".search-query", "none");
    await inSelector.expand();
    await inSelector.selectRowByValue("unassigned");
    assert
      .dom(".search-query")
      .hasValue(
        "none in:unassigned",
        'has updated search term to "none in:unassigned"'
      );
  });

  test("update assigned to through advanced search ui", async function (assert) {
    const assignedField = selectKit(".assigned-advanced-search .select-kit");

    await visit("/search");

    await fillIn(".search-query", "none");
    await assignedField.expand();

    await assignedField.fillInFilter("admin");
    await assignedField.selectRowByValue("admin");

    assert.strictEqual(
      assignedField.header().value(),
      "admin",
      'has "admin" filled in'
    );

    assert
      .dom(".search-query")
      .hasValue(
        "none assigned:admin",
        'has updated search term to "none assigned:admin"'
      );
  });
});
