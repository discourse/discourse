import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiConceptsList from "discourse/plugins/discourse-ai/discourse/components/ai-concepts-list";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

module("Integration | Component | AiConceptsList", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );
  });

  test("renders concepts, aliases, parent info, and disabled notice", async function (assert) {
    const model = {
      ai_concepts: [
        {
          id: 1,
          name: "Kubernetes",
          description: "Container orchestration",
          aliases: ["k8s", "kube"],
          status: "active",
          parent_name: "Infrastructure",
          topics_count: 14,
          posts_count: 3,
        },
        {
          id: 2,
          name: "Service Mesh",
          description: "",
          aliases: [],
          status: "candidate",
          parent_name: null,
          topics_count: 1,
          posts_count: 0,
        },
      ],
      meta: {
        total: 2,
        page: 1,
        per_page: 50,
        has_more: false,
        counts: { active: 1, candidate: 1, retired: 0 },
        enabled: false,
        embeddings_enabled: true,
      },
    };

    await render(<template><AiConceptsList @model={{model}} /></template>);

    assert
      .dom(".ai-concepts-list__disabled-notice")
      .exists("shows notice when inferred concepts are disabled");
    assert
      .dom(".ai-concepts-list__curate-btn")
      .doesNotExist("hides Run curation when feature is disabled");
    assert
      .dom(".ai-concepts-list__row")
      .exists({ count: 2 }, "renders a row for each concept");
    assert
      .dom('[data-concept-id="1"] .ai-concepts-list__alias')
      .exists({ count: 2 }, "renders alias chips");
    assert
      .dom('[data-concept-id="2"] .ai-concept-status')
      .hasAttribute("data-status", "candidate", "displays status attribute");
  });

  test("promotes a candidate concept and runs curation", async function (assert) {
    let promotePayload = null;
    let curateCalled = false;

    pretender.put("/admin/plugins/discourse-ai/ai-concepts/2.json", (req) => {
      promotePayload = JSON.parse(req.requestBody);
      return response(200, {
        ai_concept: { id: 2, name: "Service Mesh", status: "active" },
      });
    });

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", () => {
      return response(200, {
        ai_concepts: [
          {
            id: 2,
            name: "Service Mesh",
            aliases: [],
            status: "active",
            topics_count: 1,
            posts_count: 0,
          },
        ],
        meta: {
          total: 1,
          page: 1,
          per_page: 50,
          has_more: false,
          counts: { active: 1, candidate: 0, retired: 0 },
          enabled: true,
          embeddings_enabled: true,
        },
      });
    });

    pretender.post(
      "/admin/plugins/discourse-ai/ai-concepts/curate.json",
      () => {
        curateCalled = true;
        return response(204, {});
      }
    );

    const model = {
      ai_concepts: [
        {
          id: 2,
          name: "Service Mesh",
          aliases: [],
          status: "candidate",
          topics_count: 1,
          posts_count: 0,
        },
      ],
      meta: {
        total: 1,
        page: 1,
        per_page: 50,
        has_more: false,
        counts: { active: 0, candidate: 1, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
      },
    };

    await render(<template><AiConceptsList @model={{model}} /></template>);

    await click('[data-concept-id="2"] .ai-concepts-list__actions-menu');
    await click(".ai-concepts-list__promote-btn");

    assert.strictEqual(
      promotePayload.ai_concept.status,
      "active",
      "sends active status on promote"
    );
    assert
      .dom('[data-concept-id="2"] .ai-concept-status')
      .hasAttribute("data-status", "active", "refreshes row to active");

    await click(".ai-concepts-list__curate-btn");
    assert.true(curateCalled, "enqueues curation when Run curation is clicked");
  });

  test("shows empty list when no concepts exist and no-results state when filtered", async function (assert) {
    const emptyModel = {
      ai_concepts: [],
      meta: {
        counts: { active: 0, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
      },
    };

    await render(<template><AiConceptsList @model={{emptyModel}} /></template>);
    assert
      .dom(".admin-config-area-empty-list")
      .exists("renders AdminConfigAreaEmptyList when no concepts exist");

    const filteredEmptyModel = {
      ai_concepts: [],
      meta: {
        counts: { active: 2, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
      },
    };

    await render(
      <template>
        <AiConceptsList @filter="unknown" @model={{filteredEmptyModel}} />
      </template>
    );
    assert
      .dom(".ai-concepts-list__no-results")
      .exists("renders no-results message when filters match nothing");
  });

  test("allows starting and tracking initial seed from the empty state when enabled", async function (assert) {
    let seedCalled = false;

    pretender.post("/admin/plugins/discourse-ai/ai-concepts/seed.json", () => {
      seedCalled = true;
      return response(200, {
        seed_status: {
          status: "queued",
          processed: 0,
          total: 0,
        },
      });
    });

    const emptyEnabledModel = {
      ai_concepts: [],
      meta: {
        counts: { active: 0, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
        seed_status: null,
      },
    };

    await render(
      <template><AiConceptsList @model={{emptyEnabledModel}} /></template>
    );

    assert
      .dom(".ai-concepts-list__empty-description")
      .exists("renders explanatory text on the enabled empty state");
    assert
      .dom(".ai-concepts-list__seed-btn")
      .exists("renders Seed concepts button when enabled and empty");

    await click(".ai-concepts-list__seed-btn");

    assert.true(seedCalled, "posts to the seed endpoint when clicked");
    assert
      .dom(".ai-concepts-list__seed-status")
      .exists("shows queued status banner after starting seed");
    assert
      .dom(".ai-concepts-list__refresh-btn")
      .exists("shows Refresh button while seeding");

    const emptyDisabledModel = {
      ai_concepts: [],
      meta: {
        counts: { active: 0, candidate: 0, retired: 0 },
        enabled: false,
        embeddings_enabled: true,
        seed_status: null,
      },
    };

    await render(
      <template><AiConceptsList @model={{emptyDisabledModel}} /></template>
    );

    assert
      .dom(".ai-concepts-list__seed-btn")
      .doesNotExist("hides Seed concepts button when feature is disabled");
  });
});
