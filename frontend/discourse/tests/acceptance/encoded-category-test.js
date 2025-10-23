import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

  test("Visit subcategory by slug", async function (assert) {
    const bodyClass =
      "category-%E6%BC%A2%E5%AD%97-parent-%E6%BC%A2%E5%AD%97-subcategory";

    await visit("/c/%E6%BC%A2%E5%AD%97-parent/%E6%BC%A2%E5%AD%97-subcategory");
    assert.dom(document.body).hasClass(bodyClass, "has the default navigation");
    assert.dom(".topic-list").exists("The list of topics was rendered");
    assert.dom(".topic-list .topic-list-item").exists("has topics");

    await visit("/c/漢字-parent/漢字-subcategory");
    assert.dom(document.body).hasClass(bodyClass, "has the default navigation");
    assert.dom(".topic-list").exists("The list of topics was rendered");
    assert.dom(".topic-list .topic-list-item").exists("has topics");
  });
});
