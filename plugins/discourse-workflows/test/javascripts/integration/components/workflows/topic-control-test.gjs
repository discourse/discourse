import { tracked } from "@glimmer/tracking";
import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import TopicControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/topic-control";

const TOPICS = [
  { id: 280, title: "Cube challenge", fancy_title: "Cube challenge" },
  { id: 34, title: "Cube leaderboard", fancy_title: "Cube leaderboard" },
];

class TestField {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  set(newValue) {
    this.value = newValue;
  }
}

function searchResponse(term) {
  const topics = TOPICS.filter(
    (topic) =>
      String(topic.id) === term ||
      topic.title.toLowerCase().includes(term.toLowerCase())
  );

  return {
    posts: topics.map((topic) => ({
      id: topic.id * 10,
      topic_id: topic.id,
      blurb: "",
    })),
    topics: topics.map((topic) => ({ ...topic, slug: "cube", category_id: 1 })),
    grouped_search_result: { term, type_filter: "topic" },
  };
}

async function renderControl(context, value) {
  context.field = new TestField(value);

  await render(
    <template>
      <TopicControl @field={{context.field}} @supportsExpression={{false}} />
    </template>
  );
}

module("Integration | Component | Workflows | TopicControl", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/search/query", (request) =>
      response(searchResponse(request.queryParams.term))
    );
  });

  test("stores an array of topic ids", async function (assert) {
    await renderControl(this, []);

    const selector = selectKit(".topic-selector");

    await selector.expand();
    await selector.fillInFilter("cube");
    await selector.selectRowByValue(280);

    assert.deepEqual(this.field.value, [280], "stores the first selection");

    await selector.fillInFilter("leaderboard");
    await selector.selectRowByValue(34);

    assert.deepEqual(this.field.value, [280, 34], "appends later selections");
  });

  test("hydrates selected topics from stored ids", async function (assert) {
    await renderControl(this, [280]);

    await waitFor(".topic-selector .select-kit-header[data-value='280']");

    assert
      .dom(".topic-selector .select-kit-header")
      .includesText("Cube challenge", "shows the topic title");
  });

  test("shows unresolvable ids and drops non-numeric entries", async function (assert) {
    await renderControl(this, ["=$json.topic_ids", 999]);

    await waitFor(".topic-selector .select-kit-header[data-value='999']");

    assert.strictEqual(
      selectKit(".topic-selector").header().value(),
      "999",
      "keeps only the numeric id"
    );
    assert
      .dom(".topic-selector .select-kit-header")
      .includesText("Topic #999", "shows a placeholder for the missing topic");
  });
});
