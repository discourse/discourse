import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiAgentFlair from "discourse/plugins/discourse-ai/discourse/components/post/ai-agent-flair";

module("Integration | Component | AiAgentFlair", function (hooks) {
  setupRenderingTest(hooks);

  test("replaces the technical username with agent and model attribution", async function (assert) {
    this.outletArgs = {
      post: {
        ai_agent_id: -7,
        ai_agent_name: "Forum helper",
        llm_name: "Model snapshot",
        topic: {},
      },
      user: {
        username: "forum_helper_bot",
      },
    };

    await render(
      <template>
        <AiAgentFlair @outletArgs={{this.outletArgs}}>
          <span class="technical-name">forum_helper_bot</span>
        </AiAgentFlair>
      </template>
    );

    assert.dom(".technical-name").doesNotExist();
    assert
      .dom(".agent-flair a")
      .hasText("Forum helper")
      .hasAttribute("href", "/u/forum_helper_bot");
    assert.dom(".agent-flair__model").hasText("Model snapshot");
  });

  test("preserves the original author for legacy model attribution", async function (assert) {
    this.outletArgs = {
      post: {
        llm_name: "Legacy model",
        topic: {},
      },
    };

    await render(
      <template>
        <AiAgentFlair @outletArgs={{this.outletArgs}}>
          <span class="technical-name">Legacy model user</span>
        </AiAgentFlair>
      </template>
    );

    assert
      .dom(".technical-name")
      .hasText("Legacy model user", "the historical author remains visible");
    assert
      .dom(".agent-flair")
      .doesNotExist("no agent replaces the historical author");
    assert
      .dom(".agent-flair__model")
      .hasText("Legacy model", "the historical model remains attributed");
  });

  test("does not relabel a historical post with the topic's current agent", async function (assert) {
    this.outletArgs = {
      post: {
        llm_name: "Historical model",
        topic: {
          ai_agent_name: "Current topic agent",
        },
      },
    };

    await render(
      <template>
        <AiAgentFlair @outletArgs={{this.outletArgs}}>
          <span class="technical-name">Historical author</span>
        </AiAgentFlair>
      </template>
    );

    assert
      .dom(".technical-name")
      .hasText("Historical author", "the response keeps its own author");
    assert
      .dom(".agent-flair")
      .doesNotExist("the current topic agent is not presented as the author");
    assert
      .dom(".agent-flair__model")
      .hasText("Historical model", "the response keeps its model snapshot");
  });
});
