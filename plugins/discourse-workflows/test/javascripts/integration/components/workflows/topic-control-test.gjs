import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { click, findAll, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import TopicControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/topic-control";

const TOPICS = [
  { id: 280, title: "Cube challenge", fancy_title: "Cube challenge" },
  { id: 34, title: "Cube leaderboard", fancy_title: "Cube leaderboard" },
];

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
  context.field = tracked(value);

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

module(
  "Integration | Component | Workflows | TopicControl | new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.searches = [];
      this.lookups = [];
      pretender.get("/search/query", (request) => {
        this.searches.push(request.queryParams);
        return response(searchResponse(request.queryParams.term.trim()));
      });
      pretender.get("/topics/lookup.json", (request) => {
        const ids = []
          .concat(request.queryParams.topic_ids ?? [])
          .map((id) => parseInt(id, 10));
        this.lookups.push(ids);
        return response({
          topics: TOPICS.filter((topic) => ids.includes(topic.id)),
        });
      });
    });

    /** Searches for `term` and picks the row titled `title`. */
    async function pick(select, term, title) {
      await select.open();
      await select.search(term);
      await click(
        findAll("[role='option']").find((row) =>
          row.textContent.includes(title)
        )
      );
    }

    test("stores an array of topic ids, searching every archetype", async function (assert) {
      await renderControl(this, []);
      const select = new DSelect(".topic-selector");

      await pick(select, "cube", "Cube challenge");
      assert.deepEqual(this.field.value, [280], "stores the first selection");

      await pick(select, "leaderboard", "Cube leaderboard");
      assert.deepEqual(this.field.value, [280, 34], "appends later selections");
      assert.deepEqual(this.searches[0], {
        term: "cube ",
        type_filter: "topic",
        search_for_id: "true",
      });
    });

    test("searches what the trigger's topic type watches", async function (assert) {
      const topicType = tracked("topics");
      this.field = tracked([]);
      const field = this.field;
      await render(
        <template>
          <TopicControl
            @configuration={{hash topic_type=topicType.value}}
            @field={{field}}
            @supportsExpression={{false}}
          />
        </template>
      );
      const select = new DSelect(".topic-selector");

      await select.open();
      await select.search("cube");
      assert.deepEqual(
        this.searches.at(-1),
        {
          term: "cube ",
          type_filter: "topic",
          restrict_to_archetype: "regular",
          search_for_id: "true",
        },
        "topics: regular topics only"
      );
      await select.close();

      topicType.value = "personal_messages";
      await settled();
      await select.open();
      await select.search("cube");
      assert.deepEqual(
        this.searches.at(-1),
        {
          term: "cube in:all-pms",
          type_filter: "private_messages",
          restrict_to_archetype: "private_message",
          search_for_id: "true",
        },
        "personal messages: every user's messages"
      );
      await select.close();

      topicType.value = "all";
      await settled();
      await select.open();
      await select.search("cube");
      assert.deepEqual(
        this.searches.at(-1),
        { term: "cube ", type_filter: "topic", search_for_id: "true" },
        "all: every topic, with messages by id or URL"
      );
    });

    test("names stored topics through one lookup", async function (assert) {
      await renderControl(this, [280, 34]);

      assert.deepEqual(this.lookups, [[280, 34]]);
      assert
        .dom(".topic-selector")
        .hasAttribute("data-name", "Cube challenge,Cube leaderboard");
    });

    test("names unresolvable ids and drops non-numeric entries", async function (assert) {
      await renderControl(this, ["=$json.topic_ids", 999]);

      assert.dom(".topic-selector").hasAttribute("data-value", "999");
      assert.dom(".topic-selector").hasAttribute("data-name", "Topic #999");
    });
  }
);
