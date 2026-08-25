/* eslint-disable qunit/no-conditional-assertions */
import Service from "@ember/service";
import { click, fillIn, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "discourse/plugins/discourse-ai/discourse/components/ai-search-discoveries";

module("Integration | Component | AiSearchDiscoveries", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.ai_discover_enabled = true;
    this.siteSettings.ai_discover_summary_detail = "balanced";
    this.siteSettings.ai_discover_related_count = 2;
    this.currentUser.can_use_ai_discover_agent = true;

    this.closeSearchMenuCalled = false;
    this.closeSearchMenu = () => {
      this.closeSearchMenuCalled = true;
    };

    sinon.stub(DiscourseURL, "routeTo");
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("renders the Discoveries label and structured answer title", async function (assert) {
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discoveryTitle = "Two Miyazakis, two bodies of work";
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showHeading={{true}} />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__title")
      .hasText("Discoveries", "the result has the agreed heading");
    assert
      .dom(".ai-search-discoveries__title .d-icon-far-circle")
      .exists("the result label uses the agreed status marker");
    assert
      .dom(".ai-search-discoveries__answer-title")
      .hasText(
        "Two Miyazakis, two bodies of work",
        "the model-provided title introduces the answer"
      );
  });

  test("hides the structured answer title in Quiet mode", async function (assert) {
    this.siteSettings.ai_discover_summary_detail = "quiet";
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discoveryTitle = "Two Miyazakis, two bodies of work";
        streamedText = "A concise answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showHeading={{true}} />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__answer-title")
      .doesNotExist("Quiet presents the concise answer without a header");
  });

  test("marks the full-page presentation for a top-of-results layout", async function (assert) {
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discoveryTitle = "Two Miyazakis, two bodies of work";
        streamedText = "A useful answer.";
        sources = [
          {
            title: "A selected discussion",
            url: "/t/a-selected-discussion/123",
          },
        ];
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="miyazaki"
          @showHeading={{true}}
          @fullPage={{true}}
        />
      </template>
    );

    assert
      .dom(".ai-search-discoveries")
      .hasClass("--full-page", "the full-page layout has an explicit modifier");
    assert
      .dom(".ai-discovery-sources")
      .doesNotExist(
        "selected discussions use the normal full-page results instead of cards"
      );
  });

  test("shows the requested discussions and links to all matching posts", async function (assert) {
    this.siteSettings.ai_discover_related_count = 3;
    const sources = [
      {
        title: "Recurring ideas across Hayao Miyazaki’s films",
        url: "/t/hayao-miyazaki/101/1",
        excerpt: "Flight, nature, work, and resilient protagonists.",
        category: "Studio Ghibli",
        topic_replies: 12,
        username: "hayao",
        name: "Hayao Miyazaki",
        avatar_template: "/letter_avatar_proxy/v4/letter/h/9de053/{size}.png",
      },
      {
        title: "Gorō Miyazaki: architecture and direction",
        url: "/t/goro-miyazaki/102/1",
        excerpt: "Architecture, inheritance, and a different visual voice.",
        category: "Studio Ghibli",
        topic_replies: 8,
        username: "goro",
        name: "Gorō Miyazaki",
        avatar_template: "/letter_avatar_proxy/v4/letter/g/4491bb/{size}.png",
      },
      {
        title: "Visual craft in The Boy and the Heron",
        url: "/t/the-boy-and-the-heron/103/1",
        excerpt: "Grief, sound, and worldbuilding.",
        category: "Studio Ghibli",
        topic_replies: 6,
      },
      {
        title: "Flight across the filmography",
        url: "/t/flight/104/1",
        excerpt: "Machines, escape, and the cost of flight.",
        category: "Studio Ghibli",
        topic_replies: 9,
      },
    ];

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        sources = sources;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showSources={{true}} />
      </template>
    );

    assert
      .dom(".ai-discovery-sources__title")
      .hasText("Related discussions", "the source group is clearly labelled");
    assert
      .dom(".ai-discovery-sources__item")
      .exists({ count: 3 }, "the configured number of discussions is shown");
    assert
      .dom(".ai-discovery-source__avatar .avatar")
      .exists({ count: 2 }, "discussion cards show their source authors");
    assert
      .dom(".ai-discovery-sources__toggle")
      .doesNotExist("there is no local source expansion control");
    assert
      .dom(".ai-discovery-sources__header .ai-discovery-sources__all-results")
      .hasText(
        "Show all matching posts",
        "full search replaces the expansion control"
      );
    assert
      .dom(".ai-discovery-sources__all-results .d-icon-arrow-right")
      .exists("the full search link communicates forward navigation");
    assert
      .dom(".ai-discovery-sources__all-results")
      .hasAttribute(
        "href",
        "/search?q=miyazaki",
        "full search keeps the active query"
      );
    assert.strictEqual(
      getComputedStyle(find(".ai-discovery-source__title")).color,
      getComputedStyle(find(".ai-discovery-sources__all-results")).color,
      "discussion titles use the standard link color"
    );
  });

  test("omits zero reply counts from discussion cards", async function (assert) {
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        sources = [
          {
            title: "A discussion without replies",
            url: "/t/without-replies/101/1",
            category: "Studio Ghibli",
            topic_replies: 0,
          },
          {
            title: "A discussion with replies",
            url: "/t/with-replies/102/1",
            category: "Support",
            topic_replies: 4,
          },
        ];

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showSources={{true}} />
      </template>
    );

    assert
      .dom(
        ".ai-discovery-sources__item:nth-child(1) .ai-discovery-source__metadata"
      )
      .hasText("Studio Ghibli", "zero replies and their separator are omitted");
    assert
      .dom(
        ".ai-discovery-sources__item:nth-child(2) .ai-discovery-source__metadata"
      )
      .hasText("Support · 4 replies", "non-zero reply counts remain visible");
  });

  test("does not show result preferences in the Discoveries result", async function (assert) {
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showHeading={{true}} />
      </template>
    );

    assert
      .dom(".ai-discovery-preferences-menu")
      .doesNotExist("result density is configured by site settings");
  });

  test("clicking a link in discovery text closes search menu", async function (assert) {
    const discovery = {
      streamedText:
        "Here is some discovery text with a [link](/t/some-topic/123).",
      loadingDiscoveries: false,
      isStreaming: false,
      discoveryTimedOut: false,
    };

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = discovery.streamedText;
        loadingDiscoveries = discovery.loadingDiscoveries;
        isStreaming = discovery.isStreaming;
        discoveryTimedOut = discovery.discoveryTimedOut;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    pretender.get("/discourse-ai/discoveries", () => [
      200,
      { "Content-Type": "application/json" },
      {},
    ]);

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="test search"
          @closeSearchMenu={{this.closeSearchMenu}}
        />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__discovery")
      .exists("discovery content is rendered");

    const link = document.querySelector(".ai-search-discoveries__discovery a");
    assert.strictEqual(link?.tagName, "A", "link exists in discovery text");

    await click(link);

    assert.true(
      this.closeSearchMenuCalled,
      "closeSearchMenu was called after clicking link"
    );
    assert.true(
      DiscourseURL.routeTo.calledOnce,
      "DiscourseURL.routeTo was called"
    );
    assert.true(
      DiscourseURL.routeTo.calledWith(sinon.match("/t/some-topic/123")),
      "routed to correct URL"
    );
  });

  test("clicking a link with ctrl/cmd does not close search menu", async function (assert) {
    const discovery = {
      streamedText:
        "Here is some discovery text with a [link](/t/some-topic/123).",
      loadingDiscoveries: false,
      isStreaming: false,
      discoveryTimedOut: false,
    };

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = discovery.streamedText;
        loadingDiscoveries = discovery.loadingDiscoveries;
        isStreaming = discovery.isStreaming;
        discoveryTimedOut = discovery.discoveryTimedOut;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    pretender.get("/discourse-ai/discoveries", () => [
      200,
      { "Content-Type": "application/json" },
      {},
    ]);

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="test search"
          @closeSearchMenu={{this.closeSearchMenu}}
        />
      </template>
    );

    const link = document.querySelector(".ai-search-discoveries__discovery a");
    assert.strictEqual(link?.tagName, "A", "link exists in discovery text");

    const clickEvent = new MouseEvent("click", {
      bubbles: true,
      cancelable: true,
      ctrlKey: true,
    });
    link.dispatchEvent(clickEvent);

    assert.false(
      this.closeSearchMenuCalled,
      "closeSearchMenu was not called when ctrl+clicking"
    );
    assert.false(
      DiscourseURL.routeTo.called,
      "DiscourseURL.routeTo was not called for new window navigation"
    );
  });

  test("clicking non-link content does not close search menu", async function (assert) {
    const discovery = {
      streamedText:
        "Here is some discovery text with a [link](/t/some-topic/123) and plain text.",
      loadingDiscoveries: false,
      isStreaming: false,
      discoveryTimedOut: false,
    };

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = discovery.streamedText;
        loadingDiscoveries = discovery.loadingDiscoveries;
        isStreaming = discovery.isStreaming;
        discoveryTimedOut = discovery.discoveryTimedOut;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    pretender.get("/discourse-ai/discoveries", () => [
      200,
      { "Content-Type": "application/json" },
      {},
    ]);

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="test search"
          @closeSearchMenu={{this.closeSearchMenu}}
        />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__discovery")
      .exists("discovery content is rendered");

    const paragraph = document.querySelector(
      ".ai-search-discoveries__discovery p"
    );

    if (paragraph) {
      await click(paragraph);

      assert.false(
        this.closeSearchMenuCalled,
        "closeSearchMenu was not called when clicking non-link content"
      );
      assert.false(
        DiscourseURL.routeTo.called,
        "DiscourseURL.routeTo was not called"
      );
    } else {
      assert.strictEqual(
        document.querySelector(".ai-search-discoveries__discovery")?.tagName,
        "ARTICLE",
        "article exists"
      );
    }
  });

  test("asks a follow-up using only the server-owned request context", async function (assert) {
    let submittedBody;
    this.owner.register(
      "service:composer",
      class extends Service {
        focusComposer = sinon.stub();
      }
    );
    const composer = this.owner.lookup("service:composer");
    DiscourseURL.routeTo.callsFake((_url, options) =>
      options?.afterRouteComplete?.()
    );
    this.currentUser.ai_enabled_agents = [
      {
        id: -1,
        username: "forum_helper",
        allow_personal_messages: true,
      },
    ];
    this.currentUser.ai_enabled_chat_bots = [
      { id: -1200, username: "ai_bot", llm_model_id: 1 },
    ];
    this.siteSettings.ai_bot_enabled = true;
    this.siteSettings.ai_discover_agent = "-34";
    this.siteSettings.ai_discover_follow_up_agent = "-1";

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discovery = "A useful answer.";
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        activeRequestId = "13e16948-6a2a-42f4-80b4-5acac1f74713";

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );
    pretender.post("/discourse-ai/discoveries/continue-convo", (request) => {
      submittedBody = new URLSearchParams(request.requestBody);
      return [
        200,
        { "Content-Type": "application/json" },
        { success: "OK", topic_id: 321 },
      ];
    });

    await render(
      <template><AiSearchDiscoveries @searchTerm="test search" /></template>
    );
    await fillIn(
      ".ai-search-discoveries__follow-up-input",
      "Which guide should I read first?"
    );
    await click(".ai-search-discoveries__follow-up-submit");

    assert.strictEqual(
      submittedBody.get("request_id"),
      "13e16948-6a2a-42f4-80b4-5acac1f74713"
    );
    assert.false(submittedBody.has("query"));
    assert.false(submittedBody.has("context"));
    assert.strictEqual(
      submittedBody.get("question"),
      "Which guide should I read first?"
    );
    assert.false(
      composer.focusComposer.called,
      "the reply composer stays closed while the conversation loads"
    );
  });

  test("only offers a follow-up when the AI bot can receive personal messages", async function (assert) {
    this.currentUser.ai_enabled_agents = [
      {
        id: -1,
        username: "forum_helper",
        allow_personal_messages: true,
      },
    ];
    this.currentUser.ai_enabled_chat_bots = [
      { id: -1200, username: "ai_bot", llm_model_id: 1 },
    ];
    this.siteSettings.ai_discover_agent = "-34";
    this.siteSettings.ai_discover_follow_up_agent = "-1";

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discovery = "A useful answer.";
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    this.siteSettings.ai_bot_enabled = false;
    await render(
      <template><AiSearchDiscoveries @searchTerm="test search" /></template>
    );
    assert
      .dom(".ai-search-discoveries__continue-conversation")
      .doesNotExist("the field is hidden when the AI bot is disabled");

    this.siteSettings.ai_bot_enabled = true;
    this.currentUser.ai_enabled_agents[0].allow_personal_messages = false;
    await render(
      <template><AiSearchDiscoveries @searchTerm="test search" /></template>
    );
    assert
      .dom(".ai-search-discoveries__continue-conversation")
      .doesNotExist("the field is hidden when the agent does not allow PMs");
  });

  test("does not use the discovery agent as the follow-up agent", async function (assert) {
    this.currentUser.ai_enabled_agents = [
      {
        id: -34,
        username: "discover",
        allow_personal_messages: true,
      },
    ];
    this.currentUser.ai_enabled_chat_bots = [
      { id: -1200, username: "ai_bot", llm_model_id: 1 },
    ];
    this.siteSettings.ai_bot_enabled = true;
    this.siteSettings.ai_discover_agent = "-34";
    this.siteSettings.ai_discover_follow_up_agent = "-1";

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discovery = "A useful answer.";
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template><AiSearchDiscoveries @searchTerm="test search" /></template>
    );

    assert
      .dom(".ai-search-discoveries__continue-conversation")
      .doesNotExist("the selected follow-up agent must be available");
  });

  test("shows a useful no-answer state after completion", async function (assert) {
    this.currentUser.can_create_topic = true;
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        answerable = false;
        streamedText = "";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="unsupported question"
          @showHeading={{true}}
        />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__title")
      .hasText(i18n("discourse_ai.discobot_discoveries.main_title"));
    assert
      .dom(".ai-search-discoveries__no-answer-message")
      .hasText(i18n("discourse_ai.discobot_discoveries.no_answer"));
    assert
      .dom(".ai-search-discoveries__create-topic")
      .hasText(i18n("discourse_ai.discobot_discoveries.create_topic"))
      .hasClass("btn-primary", "Create topic is the primary next action");
  });

  test("uses enabled AI helpers to prepare the new topic", async function (assert) {
    const composerModel = {
      title: "",
      categoryId: 4,
      tags: [],
      privateMessage: false,
      set(name, value) {
        this[name] = value;
      },
    };
    let openedTitle;
    let tagRequest;

    this.currentUser.can_create_topic = true;
    this.currentUser.can_use_assistant = true;
    this.currentUser.can_tag_topics = true;
    this.siteSettings.discourse_ai_enabled = true;
    this.siteSettings.ai_helper_enabled = true;
    this.siteSettings.ai_helper_enabled_features = ["suggestions"];
    this.siteSettings.ai_helper_title_suggestions_agent = "-23";
    this.siteSettings.ai_embeddings_enabled = true;

    this.owner.register(
      "service:composer",
      class extends Service {
        model = composerModel;

        async openNewTopic({ title }) {
          openedTitle = title;
          this.model.title = title;
        }
      }
    );
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        answerable = false;
        streamedText = "";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    pretender.post("/discourse-ai/ai-helper/suggest_title", () => [
      200,
      { "Content-Type": "application/json" },
      { suggestions: ["How do I catch a Pokémon?"] },
    ]);
    pretender.post("/discourse-ai/ai-helper/suggest_category", () => [
      200,
      { "Content-Type": "application/json" },
      { assistant: [{ id: 125, name: "Pokemon" }] },
    ]);
    pretender.post("/discourse-ai/ai-helper/suggest_tags", (request) => {
      tagRequest = new URLSearchParams(request.requestBody);
      return [
        200,
        { "Content-Type": "application/json" },
        { assistant: [{ id: 1, name: "games" }] },
      ];
    });

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="how do i catch a pokemon"
          @closeSearchMenu={{this.closeSearchMenu}}
        />
      </template>
    );
    await click(".ai-search-discoveries__create-topic");

    assert.true(this.closeSearchMenuCalled, "the search menu closes");
    assert.strictEqual(
      openedTitle,
      "how do i catch a pokemon",
      "the original question opens the composer immediately"
    );
    assert.strictEqual(
      composerModel.title,
      "How do I catch a Pokémon?",
      "the title helper can improve the title"
    );
    assert.strictEqual(
      composerModel.categoryId,
      125,
      "the category helper can choose a category"
    );
    assert.deepEqual(composerModel.tags, ["games"], "the tag helper adds tags");
    assert.strictEqual(
      tagRequest.get("category_id"),
      "125",
      "tags are suggested for the selected category"
    );
  });
});
