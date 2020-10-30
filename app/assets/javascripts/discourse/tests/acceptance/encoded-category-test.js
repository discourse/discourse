import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";

acceptance("Encoded Sub Category Discovery", function (needs) {
  needs.settings({
    slug_generation_method: "encoded",
  });
  needs.site({
    categories: [
      {
        id: 5,
        name: "漢字-parent",
        slug: "%E6%BC%A2%E5%AD%97-parent",
        permission: null,
      },
      {
        id: 6,
        name: "漢字-subcategory",
        slug: "%E6%BC%A2%E5%AD%97-subcategory",
        permission: null,
        parent_category_id: 5,
      },
    ],
  });
  needs.pretender((server, helper) => {
    server.get(
      "/c/%E6%BC%A2%E5%AD%97-parent/%E6%BC%A2%E5%AD%97-subcategory/6/l/latest.json",
      () => {
        return helper.response(
          DiscoveryFixtures["/latest_can_create_topic.json"]
        );
      }
    );
    server.get(
      "/c/%E6%BC%A2%E5%AD%97-parent/%E6%BC%A2%E5%AD%97-subcategory/find_by_slug.json",
      () => {
        //respond with an error here: these tests are to check that ember can route this itself without falling back to rails
        return helper.response(500, {});
      }
    );
  });

  test("Visit subcategory by slug", async (assert) => {
    let bodySelector =
      "body.category-\\%E6\\%BC\\%A2\\%E5\\%AD\\%97-parent-\\%E6\\%BC\\%A2\\%E5\\%AD\\%97-subcategory";
    await visit("/c/%E6%BC%A2%E5%AD%97-parent/%E6%BC%A2%E5%AD%97-subcategory");
    assert.ok($(bodySelector).length, "has the default navigation");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");

    await visit("/c/漢字-parent/漢字-subcategory");
    assert.ok($(bodySelector).length, "has the default navigation");
    assert.ok(exists(".topic-list"), "The list of topics was rendered");
    assert.ok(exists(".topic-list .topic-list-item"), "has topics");
  });
});
