import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
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
            parent_id: null,
            parent_name: null,
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
        parent_name: null,
      },
      topics: [],
      children: [],
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

  test("renders child concepts, parent chooser label, and tagged topics when editing", async function (assert) {
    const model = {
      isNew: false,
      concept: {
        id: 2,
        name: "Kubernetes",
        description: "Container orchestration",
        aliases: ["k8s"],
        status: "active",
        parent_id: 1,
        parent_name: "Infrastructure",
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
    };

    await render(<template><AiConceptEditor @model={{model}} /></template>);

    assert.strictEqual(
      selectKit(".ai-concept-editor__parent-chooser").header().name(),
      "Infrastructure",
      "displays the current parent name without preloading all concepts"
    );
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

  test("searches and selects a parent concept from the server", async function (assert) {
    const queries = [];
    let savedPayload = null;

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", (request) => {
      queries.push(request.queryParams);

      if (request.queryParams.filter === "Zebra") {
        return response(200, {
          ai_concepts: [
            { id: 2, name: "Kubernetes", status: "active" },
            { id: 300, name: "Zebra", status: "active" },
          ],
          meta: { has_more: false },
        });
      }

      return response(200, {
        ai_concepts: [{ id: 1, name: "Infrastructure", status: "active" }],
        meta: { has_more: true },
      });
    });

    pretender.put("/admin/plugins/discourse-ai/ai-concepts/2.json", (req) => {
      savedPayload = JSON.parse(req.requestBody);
      return response(200, {
        ai_concept: {
          id: 2,
          name: "Kubernetes",
          description: "Container orchestration",
          aliases: ["k8s"],
          status: "active",
          parent_id: 300,
          parent_name: "Zebra",
        },
      });
    });

    const model = {
      isNew: false,
      concept: {
        id: 2,
        name: "Kubernetes",
        description: "Container orchestration",
        aliases: ["k8s"],
        status: "active",
        parent_id: null,
        parent_name: null,
      },
      children: [],
      topics: [],
    };

    await render(<template><AiConceptEditor @model={{model}} /></template>);

    const chooser = selectKit(".ai-concept-editor__parent-chooser");
    await chooser.expand();
    await chooser.fillInFilter("Zebra");

    assert.false(
      chooser.rowByValue(2).exists(),
      "excludes the edited concept itself from parent options"
    );

    await chooser.selectRowByValue(300);

    assert.strictEqual(
      chooser.header().name(),
      "Zebra",
      "displays the selected parent concept returned from server search"
    );

    await click(".ai-concept-editor__form button[type='submit']");

    const filterQuery = queries.find((q) => q.filter === "Zebra");
    assert.strictEqual(
      filterQuery.status,
      "non_retired",
      "queries non-retired concepts when searching for parent candidates"
    );
    assert.strictEqual(
      filterQuery.order,
      "name",
      "orders parent search results by name"
    );
    assert.strictEqual(
      savedPayload.ai_concept.parent_id,
      300,
      "saves the searched parent_id"
    );
  });
});
