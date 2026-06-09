import { render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import FilterQuery from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/filter-query";

module("Integration | Component | workflows filter query", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.field = { value: "", set() {} };
  });

  test("loads topic filter options by default", async function (assert) {
    let topicRequests = 0;
    pretender.get("/filter.json", () => {
      topicRequests++;
      return response(200, { topic_list: { filter_option_info: [] } });
    });

    await render(
      <template>
        <FilterQuery @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    await waitUntil(() => topicRequests === 1);

    assert.strictEqual(topicRequests, 1);
  });

  test("loads post filter options and uses the supplied placeholder", async function (assert) {
    let postRequests = 0;
    pretender.get(
      "/admin/plugins/discourse-workflows/filter-options/posts.json",
      () => {
        postRequests++;
        return response(200, {
          filter_option_info: [
            { name: "keywords:", description: "Show posts matching keywords" },
          ],
        });
      }
    );

    this.setProperties({
      placeholder:
        "Filter posts by category, tag, author, keywords, or other criteria",
      schema: { ui: { filter: "posts" } },
    });

    await render(
      <template>
        <FilterQuery
          @field={{this.field}}
          @placeholder={{this.placeholder}}
          @schema={{this.schema}}
          @supportsExpression={{false}}
        />
      </template>
    );

    await waitUntil(() => postRequests === 1);

    assert.strictEqual(postRequests, 1);
    assert
      .dom(".topic-query-filter__filter-term")
      .hasAttribute("placeholder", this.placeholder);
  });
});
