import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  clearRender,
  click,
  fillIn,
  render,
  settled,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import DataExplorerWorkflowAiQuery from "discourse/plugins/discourse-data-explorer/discourse/components/data-explorer-workflow-ai-query";
import { AI_GENERATION_TIMEOUT_MS } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-generation";

const GENERATION_ID = "workflow-query-generation";
const CHANNEL = `/discourse-data-explorer/queries/ai-generation/${GENERATION_ID}`;

class QueryState {
  @tracked value;
  disabled = false;

  constructor(value) {
    this.value = value;
  }

  @action
  set(value) {
    this.value = value;
  }
}

module(
  "Integration | Component | DataExplorerWorkflowAiQuery",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.data_explorer_ai_queries_enabled = true;
      this.siteSettings.discourse_ai_enabled = true;
      this.queryState = new QueryState("SELECT 1");
      this.node = { type: "action:sql" };
      this.nodeParameters = { operation: "raw" };
      this.schema = { control_options: { lang: "sql" } };
      this.fieldName = "query";

      pretender.post(
        "/admin/plugins/discourse-data-explorer/queries/generate.json",
        () => response({ generation_id: GENERATION_ID, status: "generating" })
      );
    });

    hooks.afterEach(function () {
      sinon.restore();
    });

    async function renderComponent(context) {
      await render(
        <template>
          <DataExplorerWorkflowAiQuery
            @field={{context.queryState}}
            @fieldName={{context.fieldName}}
            @schema={{context.schema}}
            @node={{context.node}}
            @nodeParameters={{context.nodeParameters}}
          />
        </template>
      );
    }

    async function startGeneration(prompt) {
      await fillIn(".query-ai-prompt__input", prompt);
      await click(".query-ai-prompt__regenerate");
    }

    test("renders only for an available Raw SQL query field", async function (assert) {
      await renderComponent(this);

      assert
        .dom(".data-explorer-workflow-ai-query")
        .exists("renders for the Raw SQL query field");
      assert
        .dom(".query-ai-prompt__regenerate")
        .hasText("Generate query", "offers to regenerate existing SQL");

      this.set("nodeParameters", { operation: "queries" });
      await settled();
      assert
        .dom(".data-explorer-workflow-ai-query")
        .doesNotExist("does not render for saved queries");

      this.set("nodeParameters", { operation: "raw" });
      this.set("fieldName", "code");
      await settled();
      assert
        .dom(".data-explorer-workflow-ai-query")
        .doesNotExist("does not render for unrelated code fields");

      this.set("fieldName", "query");
      this.set("node", { type: "action:code" });
      await settled();
      assert
        .dom(".data-explorer-workflow-ai-query")
        .doesNotExist("does not render for unrelated code nodes");

      this.set("node", { type: "action:sql" });
      this.siteSettings.discourse_ai_enabled = false;
      await settled();
      assert
        .dom(".data-explorer-workflow-ai-query")
        .doesNotExist("does not render when Discourse AI is unavailable");

      this.siteSettings.discourse_ai_enabled = true;
      this.siteSettings.data_explorer_ai_queries_enabled = false;
      await settled();
      assert
        .dom(".data-explorer-workflow-ai-query")
        .doesNotExist("does not render when AI query generation is disabled");
    });

    test("uses Generate for an empty SQL field", async function (assert) {
      this.queryState = new QueryState("");
      await renderComponent(this);

      assert
        .dom(".query-ai-prompt__regenerate")
        .hasText("Generate", "offers to generate an initial query");
      assert
        .dom(".query-ai-prompt__input")
        .hasAttribute(
          "placeholder",
          i18n("explorer.ai.description_placeholder"),
          "uses the initial query prompt"
        );
    });

    test("presents generation as a distinct AI area", async function (assert) {
      await renderComponent(this);

      assert
        .dom(".data-explorer-workflow-ai-query")
        .hasAttribute(
          "aria-labelledby",
          "data-explorer-workflow-ai-query-title",
          "labels the AI section"
        );
      assert
        .dom(".data-explorer-workflow-ai-query__title")
        .hasText(
          i18n("explorer.ai.workflow_title"),
          "identifies the AI assistant"
        );
      assert
        .dom(".data-explorer-workflow-ai-query__description")
        .doesNotExist("keeps the AI area concise");
      assert
        .dom(
          ".data-explorer-workflow-ai-query__icon .d-icon-discourse-sparkles"
        )
        .exists("shows the standard AI icon");
      assert
        .dom(".query-ai-prompt__regenerate")
        .hasClass("btn-primary", "emphasizes the AI action");
      assert
        .dom(".query-ai-prompt__regenerate .d-icon-arrows-rotate")
        .exists("shows the query generation icon");
    });

    test("sends the current SQL and applies a completed generation", async function (assert) {
      let requestParams;
      pretender.post(
        "/admin/plugins/discourse-data-explorer/queries/generate.json",
        (request) => {
          requestParams = new URLSearchParams(request.requestBody);
          return response({
            generation_id: GENERATION_ID,
            status: "generating",
          });
        }
      );
      await renderComponent(this);

      await startGeneration("Show active users");

      assert.strictEqual(
        requestParams.get("ai_description"),
        "Show active users",
        "sends the natural-language prompt"
      );
      assert.strictEqual(
        requestParams.get("existing_sql"),
        "SELECT 1",
        "sends the current SQL as refinement context"
      );
      assert.false(
        requestParams.has("llm_model_id"),
        "uses the site-wide default instead of a per-request override"
      );
      assert
        .dom(".query-ai-prompt__regenerate")
        .isDisabled("prevents repeat submissions while generating");
      assert
        .dom(".query-ai-prompt__regenerate")
        .hasClass("is-loading", "uses the button loading state");
      assert
        .dom(".query-ai-prompt__regenerate .loading-icon")
        .exists("shows the loading spinner inside the button");
      assert
        .dom(".query-ai-prompt__generating")
        .doesNotExist("does not render a separate loading indicator");

      await publishToMessageBus(CHANNEL, {
        generation_id: GENERATION_ID,
        status: "complete",
        sql: "SELECT id FROM users",
      });
      await settled();

      assert.strictEqual(
        this.queryState.value,
        "SELECT id FROM users",
        "applies the verified SQL to the field"
      );
      assert
        .dom(".query-ai-prompt__regenerate")
        .isEnabled("allows the generated SQL to be refined again");
    });

    test("preserves SQL and restores the prompt after a generation error", async function (assert) {
      await renderComponent(this);
      await startGeneration("Show active users");

      await publishToMessageBus(CHANNEL, {
        generation_id: GENERATION_ID,
        status: "error",
        error: "The model is unavailable",
      });
      await settled();

      assert.strictEqual(
        this.queryState.value,
        "SELECT 1",
        "does not replace SQL after an error"
      );
      assert
        .dom(".query-ai-prompt__regenerate")
        .isEnabled("allows the prompt to be retried");
      assert.strictEqual(
        this.owner.lookup("service:toasts").activeToasts.at(-1).options.data
          .message,
        "The model is unavailable",
        "shows the generation error"
      );
    });

    test("preserves SQL and restores the prompt after a request error", async function (assert) {
      pretender.post(
        "/admin/plugins/discourse-data-explorer/queries/generate.json",
        () => response(500, { errors: ["Request failed"] })
      );
      await renderComponent(this);
      await startGeneration("Show active users");

      assert.strictEqual(
        this.queryState.value,
        "SELECT 1",
        "does not replace SQL after a request error"
      );
      assert
        .dom(".query-ai-prompt__regenerate")
        .isEnabled("allows the request to be retried");
    });

    test("preserves SQL and restores the prompt after a timeout", async function (assert) {
      let timeoutCallback;
      const originalSetTimeout = window.setTimeout;
      sinon.stub(window, "setTimeout").callsFake((callback, delay, ...args) => {
        if (delay === AI_GENERATION_TIMEOUT_MS) {
          timeoutCallback = callback;
          return 123;
        }
        return originalSetTimeout(callback, delay, ...args);
      });

      await renderComponent(this);
      await startGeneration("Show active users");
      timeoutCallback();
      await settled();

      assert.strictEqual(
        this.queryState.value,
        "SELECT 1",
        "does not replace SQL after a timeout"
      );
      assert
        .dom(".query-ai-prompt__regenerate")
        .isEnabled("allows the prompt to be retried");
      assert.strictEqual(
        this.owner.lookup("service:toasts").activeToasts.at(-1).options.data
          .message,
        i18n("explorer.ai.generation_timeout"),
        "shows the timeout error"
      );
    });

    test("unsubscribes from an in-flight generation when destroyed", async function (assert) {
      const messageBus = this.owner.lookup("service:message-bus");
      const unsubscribe = sinon.spy(messageBus, "unsubscribe");
      await renderComponent(this);
      await startGeneration("Show active users");

      await clearRender();

      assert.true(
        unsubscribe.calledWith(CHANNEL),
        "removes the generation subscription"
      );
    });
  }
);
