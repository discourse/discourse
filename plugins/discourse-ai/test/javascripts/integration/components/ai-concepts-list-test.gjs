import Service from "@ember/service";
import {
  click,
  fillIn,
  find,
  focus,
  render,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
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
      .dom(".d-filter-controls__no-results")
      .exists("renders no-results message when filters match nothing");
    assert
      .dom(".d-filter-controls__no-results")
      .includesText(
        "No concepts match these filters.",
        "displays the no-results message text"
      );
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

  test("hides posts column when posts_enabled is false and shows it when true", async function (assert) {
    const baseConcept = {
      id: 1,
      name: "Kubernetes",
      aliases: [],
      status: "active",
      topics_count: 14,
      posts_count: 3,
    };

    const hiddenPostsModel = {
      ai_concepts: [baseConcept],
      meta: {
        total: 1,
        page: 1,
        per_page: 50,
        has_more: false,
        counts: { active: 1, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
        posts_enabled: false,
      },
    };

    await render(
      <template><AiConceptsList @model={{hiddenPostsModel}} /></template>
    );

    assert
      .dom(".ai-concepts-list__table thead th")
      .exists({ count: 4 }, "omits posts header when posts_enabled is false");
    assert
      .dom('[data-concept-id="1"] td')
      .exists({ count: 4 }, "omits posts cell when posts_enabled is false");

    const shownPostsModel = {
      ...hiddenPostsModel,
      meta: {
        ...hiddenPostsModel.meta,
        posts_enabled: true,
      },
    };

    await render(
      <template><AiConceptsList @model={{shownPostsModel}} /></template>
    );

    assert
      .dom(".ai-concepts-list__table thead th")
      .exists({ count: 5 }, "shows posts header when posts_enabled is true");
    assert
      .dom('[data-concept-id="1"] td')
      .exists({ count: 5 }, "shows posts cell when posts_enabled is true");
  });

  test("updates seeding progress and refreshes concepts live via MessageBus", async function (assert) {
    let refreshCount = 0;

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", () => {
      refreshCount += 1;

      if (refreshCount === 1) {
        return response(200, {
          ai_concepts: [
            {
              id: 10,
              name: "Live Concept",
              aliases: [],
              status: "candidate",
              topics_count: 5,
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
            posts_enabled: false,
            seed_status: {
              status: "running",
              run_id: "run-1",
              processed: 15,
              total: 50,
            },
          },
        });
      }

      return response(200, {
        ai_concepts: [
          {
            id: 10,
            name: "Live Concept",
            aliases: [],
            status: "active",
            topics_count: 12,
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
          posts_enabled: false,
          seed_status: {
            status: "completed",
            run_id: "run-1",
            processed: 50,
            total: 50,
          },
        },
      });
    });

    const emptyModel = {
      ai_concepts: [],
      meta: {
        counts: { active: 0, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
        posts_enabled: false,
        seed_status: {
          status: "queued",
          run_id: "run-1",
          processed: 0,
          total: 0,
        },
      },
    };

    await render(<template><AiConceptsList @model={{emptyModel}} /></template>);

    assert
      .dom(".ai-concepts-list__seed-status")
      .exists("renders initial queued seeding banner in empty state");

    await publishToMessageBus("/discourse-ai/admin/inferred-concepts/seed", {
      status: "running",
      run_id: "run-1",
      processed: 15,
      total: 50,
    });

    assert
      .dom(".ai-concepts-list__table")
      .exists("refreshes from empty state to concepts table after first wave");
    assert
      .dom(".ai-concepts-list__seed-banner")
      .includesText("15 / 50", "displays live processed count in banner");

    await publishToMessageBus("/discourse-ai/admin/inferred-concepts/seed", {
      status: "running",
      run_id: "run-1",
      processed: 5,
      total: 50,
    });

    assert
      .dom(".ai-concepts-list__seed-banner")
      .includesText("15 / 50", "ignores out-of-order lower processed counts");

    await publishToMessageBus("/discourse-ai/admin/inferred-concepts/seed", {
      status: "running",
      run_id: "run-1",
      processed: 30,
      total: 50,
    });

    assert
      .dom(".ai-concepts-list__seed-banner")
      .includesText("30 / 50", "updates banner progress on subsequent waves");

    await publishToMessageBus("/discourse-ai/admin/inferred-concepts/seed", {
      status: "completed",
      run_id: "run-1",
      processed: 50,
      total: 50,
    });

    assert
      .dom(".ai-concepts-list__seed-banner")
      .doesNotExist("hides progress banner once seeding completes");
    assert
      .dom('[data-concept-id="10"]')
      .includesText(
        "Live Concept",
        "renders refreshed concepts after completion"
      );
    assert.strictEqual(
      refreshCount,
      2,
      "refreshes list on first non-empty wave and completion"
    );
  });

  test("filters concepts in-place while preserving search input focus", async function (assert) {
    const requestedParams = [];
    const allConcepts = [
      {
        id: 1,
        name: "Kubernetes",
        aliases: ["k8s"],
        status: "active",
        topics_count: 14,
        posts_count: 0,
      },
      {
        id: 2,
        name: "Service Mesh",
        aliases: ["istio"],
        status: "candidate",
        topics_count: 3,
        posts_count: 0,
      },
    ];

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", (req) => {
      requestedParams.push(req.queryParams);

      const filter = req.queryParams.filter;
      const concepts = filter === "kube" ? [allConcepts[0]] : allConcepts;

      return response(200, {
        ai_concepts: concepts,
        meta: {
          total: concepts.length,
          page: 1,
          per_page: 50,
          has_more: false,
          counts: { active: 1, candidate: 1, retired: 0 },
          enabled: true,
          embeddings_enabled: true,
          posts_enabled: false,
        },
      });
    });

    const model = {
      ai_concepts: allConcepts,
      meta: {
        total: 2,
        page: 1,
        per_page: 50,
        has_more: false,
        counts: { active: 1, candidate: 1, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
        posts_enabled: false,
      },
    };

    await render(<template><AiConceptsList @model={{model}} /></template>);

    await focus(".d-filter-controls__input");
    await fillIn(".d-filter-controls__input", "kube");

    assert.strictEqual(
      requestedParams.at(-1)?.filter,
      "kube",
      "requests filtered concepts from the server"
    );
    assert
      .dom(".ai-concepts-list__row")
      .exists({ count: 1 }, "updates rendered rows to matching concepts");
    assert
      .dom('[data-concept-id="1"]')
      .exists("renders the matching Kubernetes row");
    assert
      .dom(".d-filter-controls__input")
      .isFocused("keeps focus in the search input after filtering");
    assert
      .dom(".d-filter-controls__input")
      .hasValue("kube", "preserves typed value in search input");

    await click(".d-filter-controls__reset");

    assert.strictEqual(
      requestedParams.at(-1)?.filter,
      undefined,
      "omits filter param after resetting filters"
    );
    assert
      .dom(".ai-concepts-list__row")
      .exists({ count: 2 }, "restores all concepts after resetting filters");
  });

  test("discards stale search responses when typing continues", async function (assert) {
    let resolveFirst;
    let secondResolved = false;

    pretender.get("/admin/plugins/discourse-ai/ai-concepts.json", (req) => {
      if (req.queryParams.filter === "k") {
        return new Promise((resolve) => (resolveFirst = resolve));
      }

      secondResolved = true;
      return response(200, {
        ai_concepts: [
          {
            id: 1,
            name: "Kubernetes",
            aliases: [],
            status: "active",
            topics_count: 14,
            posts_count: 0,
          },
        ],
        meta: {
          total: 1,
          page: 1,
          per_page: 50,
          has_more: false,
          counts: { active: 2, candidate: 0, retired: 0 },
          enabled: true,
          embeddings_enabled: true,
          posts_enabled: false,
        },
      });
    });

    const model = {
      ai_concepts: [
        {
          id: 2,
          name: "Service Mesh",
          aliases: [],
          status: "active",
          topics_count: 3,
          posts_count: 0,
        },
      ],
      meta: {
        total: 1,
        page: 1,
        per_page: 50,
        has_more: false,
        counts: { active: 2, candidate: 0, retired: 0 },
        enabled: true,
        embeddings_enabled: true,
        posts_enabled: false,
      },
    };

    await render(<template><AiConceptsList @model={{model}} /></template>);

    const input = find(".d-filter-controls__input");
    input.value = "k";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    await waitUntil(() => Boolean(resolveFirst));

    input.value = "kube";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    await waitUntil(
      () => secondResolved && Boolean(find('[data-concept-id="1"]'))
    );

    resolveFirst(
      response(200, {
        ai_concepts: [
          {
            id: 99,
            name: "Stale Concept",
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
          counts: { active: 2, candidate: 0, retired: 0 },
          enabled: true,
          embeddings_enabled: true,
          posts_enabled: false,
        },
      })
    );
    await settled();

    assert
      .dom('[data-concept-id="1"]')
      .includesText("Kubernetes", "keeps the latest search response rendered");
    assert
      .dom('[data-concept-id="99"]')
      .doesNotExist("ignores stale out-of-order search response");
  });
});
