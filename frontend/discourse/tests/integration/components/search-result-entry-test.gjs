import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchResultEntry from "discourse/components/search-result-entry";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function buildPost(owner, attrs = {}) {
  const store = owner.lookup("service:store");
  const topic = store.createRecord("topic", { id: 1, title: "A topic" });
  return store.createRecord("post", {
    id: 2,
    topic,
    topic_id: 1,
    username: "eviltrout",
    created_at: "2026-01-01T00:00:00Z",
    ...attrs,
  });
}

module("Integration | Component | SearchResultEntry", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a list item for the result", async function (assert) {
    const post = buildPost(this.owner);

    await render(
      <template>
        <SearchResultEntry @bulkSelectEnabled={{true}} @post={{post}} />
      </template>
    );

    assert
      .dom(".fps-result")
      .hasAttribute("role", "listitem")
      .hasClass("bulk-select-enabled", "marks bulk selection");
  });

  test("passes the post to the after-search-result-entry outlet", async function (assert) {
    withPluginApi((api) => {
      api.renderInOutlet(
        "after-search-result-entry",
        <template>
          <span class="probe">{{@post.id}}</span>
        </template>
      );
    });
    const post = buildPost(this.owner);

    await render(<template><SearchResultEntry @post={{post}} /></template>);

    assert.dom(".fps-result .probe").hasText("2");
  });

  test("search-result-entry-class value transformer", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "search-result-entry-class",
        ({ value, context }) => {
          if (context.post.flagged) {
            value.push("flagged-result");
          }
          return value;
        }
      );
    });
    const post = buildPost(this.owner, { flagged: true });

    await render(<template><SearchResultEntry @post={{post}} /></template>);

    assert
      .dom(".fps-result")
      .hasClass("flagged-result", "adds the transformed classes");
  });
});
