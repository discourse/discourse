import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Search - Full Page", function (needs) {
  needs.settings({ assign_enabled: true });
  needs.user({ can_assign: true, can_assign_globally: true });
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
    const inSelector = selectKit(
      ".search-advanced-options .select-kit#search-in-options"
    );

    await visit("/search");
    await click(".advanced-filters__toggle");

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
    const inSelector = selectKit(
      ".search-advanced-options .select-kit#search-in-options"
    );

    await visit("/search");
    await click(".advanced-filters__toggle");

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
    await click(".advanced-filters__toggle");

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

acceptance("Search - Full Page - new select controls", function (needs) {
  needs.settings({ assign_enabled: true, enable_new_select_controls: true });
  needs.user({ can_assign: true, can_assign_globally: true });

  let searchParams;
  needs.pretender((server, helper) => {
    server.get("/u/search/users", (request) => {
      searchParams = request.queryParams;
      return helper.response({
        users: [
          {
            username: "admin",
            name: "admin",
            avatar_template: "/images/avatar.png",
          },
        ],
        groups: [{ name: "support", full_name: "Support" }],
      });
    });
  });

  test("update assigned to through advanced search ui", async function (assert) {
    await visit("/search");
    await click(".advanced-filters__toggle");
    await fillIn(".search-query", "none");

    const assigned = dSelect(".assigned-advanced-search .d-select");
    await assigned.search("adm");
    assert.strictEqual(searchParams.include_groups, "true");
    assert.strictEqual(searchParams.assignable_groups, "true");

    await assigned.selectByName("admin");
    assert
      .dom(".search-query")
      .hasValue(
        "none assigned:admin",
        'has updated search term to "none assigned:admin"'
      );

    await assigned.clear();
    assert.dom(".search-query").hasValue("none");
  });
});
