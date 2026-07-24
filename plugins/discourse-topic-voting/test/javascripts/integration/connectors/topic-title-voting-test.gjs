import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import TopicTitleVoting from "discourse/plugins/discourse-topic-voting/discourse/connectors/topic-title/topic-title-voting";

function buildTopic(overrides = {}) {
  return {
    id: 1,
    can_vote: true,
    closed: false,
    is_nested_view: false,
    postStream: {
      firstPostPresent: false,
      loaded: false,
    },
    user_voted: false,
    vote_count: 0,
    ...overrides,
  };
}

module("Integration | Connector | TopicTitleVoting", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.topic_voting_show_who_voted = false;
  });

  test("renders after the first post is present in the flat topic stream", async function (assert) {
    this.outletArgs = {
      model: buildTopic({
        postStream: {
          firstPostPresent: true,
          loaded: true,
        },
      }),
    };

    await render(
      <template><TopicTitleVoting @outletArgs={{this.outletArgs}} /></template>
    );

    assert
      .dom(".title-voting .voting-wrapper")
      .exists("the vote box renders in the topic title");
  });

  test("does not render before the first post is present in the flat topic stream", async function (assert) {
    this.outletArgs = {
      model: buildTopic(),
    };

    await render(
      <template><TopicTitleVoting @outletArgs={{this.outletArgs}} /></template>
    );

    assert
      .dom(".title-voting .voting-wrapper")
      .doesNotExist("the flat topic guard is preserved");
  });

  test("renders for nested topics before the flat topic stream is loaded", async function (assert) {
    this.outletArgs = {
      model: buildTopic({ is_nested_view: true }),
    };

    await render(
      <template><TopicTitleVoting @outletArgs={{this.outletArgs}} /></template>
    );

    assert
      .dom(".title-voting .voting-wrapper")
      .exists("nested topics can render the vote box from topic metadata");
  });
});
