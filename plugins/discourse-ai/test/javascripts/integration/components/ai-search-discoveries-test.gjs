/* eslint-disable qunit/no-conditional-assertions */
import Service from "@ember/service";
import { click, fillIn, find, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import AiSearchDiscoveries from "discourse/plugins/discourse-ai/discourse/components/ai-search-discoveries";

module("Integration | Component | AiSearchDiscoveries", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.ai_discover_enabled = true;
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
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        discoveryTitle = "Two Miyazakis, two bodies of work";
        streamedText = "A concise answer.";
        summaryDetail = 0;
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
      .exists({ count: 2 }, "two discussions are shown by default");
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

  test("offers compact result preferences from the Discoveries menu", async function (assert) {
    const changes = [];
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = "A useful answer.";
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;
        showDiscoveryTitle = true;
        showSummary = true;
        summaryDetail = 0;
        relatedCount = 2;
        savingPreferences = false;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
        setRelatedCount(value) {
          changes.push(["related", value]);
        }

        setShowSummary(value) {
          changes.push(["summary", value]);
        }

        setSummaryDetail(value) {
          changes.push(["detail", value]);
        }
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries @searchTerm="miyazaki" @showHeading={{true}} />
      </template>
    );

    await click(".ai-discovery-preferences-menu .fk-d-menu__trigger");

    assert
      .dom(".ai-discovery-preferences")
      .exists("the preferences open in a menu");
    assert.dom(".ai-discovery-preferences__count").hasText("2");
    assert
      .dom(
        ".ai-discovery-preferences__summary-row > .ai-discovery-preferences__label"
      )
      .hasText(
        "Show useful summary",
        "the summary setting follows the same label-control layout"
      );
    assert
      .dom(
        ".ai-discovery-preferences__detail-group > .ai-discovery-preferences__label"
      )
      .hasText("Summary detail", "the detail control has a visible label");
    assert
      .dom(".ai-discovery-preferences__detail")
      .doesNotHaveClass(
        "d-segmented-control--small",
        "the three detail choices have a comfortable target size"
      );
    assert
      .dom('.ai-discovery-preferences input[value="quiet"]')
      .isChecked("Quiet is selected");
    await waitUntil(() =>
      find(".ai-discovery-preferences__detail")?.style.getPropertyValue(
        "--slider-width"
      )
    );
    assert.notStrictEqual(
      find(".ai-discovery-preferences__detail").style.getPropertyValue(
        "--slider-width"
      ),
      "",
      "Quiet has a visible selected state"
    );
    assert
      .dom('.ai-discovery-preferences input[value="detailed"] + span')
      .hasText("Detailed", "the most detailed option describes its output");

    await click(".ai-discovery-preferences__increment");
    await click(
      ".ai-discovery-preferences__summary-toggle + .d-toggle-switch__checkbox-slider"
    );
    await click('.ai-discovery-preferences input[value="detailed"]');

    assert.deepEqual(changes, [
      ["related", 3],
      ["summary", false],
      ["detail", 2],
    ]);
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

  test("offers a follow-up from selected discussions when summary prose is hidden", async function (assert) {
    this.currentUser.ai_enabled_agents = [
      {
        id: -1,
        username: null,
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
        discovery = "";
        streamedText = "";
        sources = [{ title: "A selected discussion", url: "/t/topic/1" }];
        showSummary = false;
        answerable = true;
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
      .exists("selected discussions provide server-owned follow-up context");
  });

  test("shows a useful no-answer state after completion", async function (assert) {
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

    assert.dom(".ai-search-discoveries__title").hasText("Discoveries");
    assert
      .dom(".ai-search-discoveries__no-answer")
      .hasText(
        "Discoveries couldn’t find enough useful discussion to answer this."
      );
  });
});
