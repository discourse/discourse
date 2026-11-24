import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiConceptEditor from "discourse/plugins/discourse-ai/discourse/components/ai-concept-editor";

module("Integration | Component | AiConceptEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.router = this.owner.lookup("service:router");
    sinon.stub(this.router, "transitionTo");
  });

  test("creates a new concept and parses comma-separated aliases", async function (assert) {
    let submittedPayload = null;
    pretender.post(
      "/admin/plugins/discourse-ai/ai-concepts.json",
      (request) => {
        submittedPayload = JSON.parse(request.requestBody);
        return response(201, {
          ai_concept: {
            id: 42,
            name: "Observability",
            description: "Metrics and traces",
            aliases: ["o11y", "telemetry"],
            status: "active",
            parent_id: 1,
          },
        });
      }
    );

    const model = {
      isNew: true,
      concept: {
        name: "",
        description: "",
        aliases: [],
        status: "active",
        parent_id: null,
      },
      topics: [],
      children: [],
      availableConcepts: [{ id: 1, name: "Infrastructure", status: "active" }],
    };

    await render(<template><AiConceptEditor @model={{model}} /></template>);

    await fillIn('input[name="name"]', "Observability");
    await fillIn('textarea[name="description"]', "Metrics and traces");
    await fillIn('input[name="aliases"]', "o11y, telemetry, ");
    await click(".ai-concept-editor__form button[type='submit']");

    assert.deepEqual(
      submittedPayload.ai_concept.aliases,
      ["o11y", "telemetry"],
      "parses comma-separated aliases into a trimmed array"
    );
    assert.strictEqual(
      submittedPayload.ai_concept.name,
      "Observability",
      "sends the trimmed concept name"
    );
    assert.true(
      this.router.transitionTo.calledWithExactly(
        "adminPlugins.show.discourse-ai-concepts.index"
      ),
      "navigates back to the index after creation"
    );
  });

  test("renders child concepts and tagged topics when editing", async function (assert) {
    const model = {
      isNew: false,
      concept: {
        id: 2,
        name: "Kubernetes",
        description: "Container orchestration",
        aliases: ["k8s"],
        status: "active",
        parent_id: 1,
      },
      children: [{ id: 3, name: "Helm", status: "candidate" }],
      topics: [
        {
          id: 99,
          title: "Deploying Discourse on Kubernetes",
          url: "/t/deploying-discourse-on-kubernetes/99",
          primary: true,
          relevance: 0.94,
        },
      ],
      availableConcepts: [
        { id: 1, name: "Infrastructure", status: "active" },
        { id: 2, name: "Kubernetes", status: "active" },
      ],
    };

    await render(<template><AiConceptEditor @model={{model}} /></template>);

    assert
      .dom(".ai-concept-editor__child-item")
      .includesText("Helm", "displays sub-concepts linked to this concept");
    assert
      .dom(".ai-concept-editor__topics-table")
      .includesText(
        "Deploying Discourse on Kubernetes",
        "displays tagged public topics"
      );
    assert
      .dom(".ai-concept-editor__merge-btn")
      .exists("renders the merge action button for non-retired concepts");
  });
});
