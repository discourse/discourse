/* eslint-disable qunit/no-conditional-assertions */
import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
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

  test("marks the full-page presentation for a top-of-results layout", async function (assert) {
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
  });

  test("renders the full answer when collapsing is disabled", async function (assert) {
    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        streamedText = "A useful answer with enough detail. ".repeat(20);
        loadingDiscoveries = false;
        isStreaming = false;
        discoveryTimedOut = false;

        triggerDiscovery() {}
        onDiscoveryUpdate() {}
      }
    );

    await render(
      <template>
        <AiSearchDiscoveries
          @searchTerm="miyazaki"
          @discoveryPreviewLength={{50}}
          @collapsible={{false}}
        />
      </template>
    );

    assert
      .dom(".ai-search-discoveries__discovery")
      .doesNotHaveClass("preview", "the answer is not obscured");
    assert
      .dom(".ai-search-discoveries__toggle")
      .doesNotExist("Tell me more is not rendered");
  });

  test("shows two related discussions and can reveal all sources", async function (assert) {
    const sources = [
      {
        title: "Recurring ideas across Hayao Miyazaki’s films",
        url: "/t/hayao-miyazaki/101/1",
        excerpt: "Flight, nature, work, and resilient protagonists.",
        category: "Studio Ghibli",
        topic_replies: 12,
      },
      {
        title: "Gorō Miyazaki: architecture and direction",
        url: "/t/goro-miyazaki/102/1",
        excerpt: "Architecture, inheritance, and a different visual voice.",
        category: "Studio Ghibli",
        topic_replies: 8,
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
      .dom(".ai-discovery-sources__toggle")
      .hasText(
        "View all 4",
        "the expansion control includes the available count"
      );

    await click(".ai-discovery-sources__toggle");

    assert
      .dom(".ai-discovery-sources__item")
      .exists({ count: 4 }, "all available discussions are shown on request");
    assert
      .dom(".ai-discovery-sources__toggle")
      .hasText("Show fewer", "the expansion is reversible");
    assert
      .dom(".ai-discovery-sources__all-results")
      .hasText("Show all matching posts", "full search remains available");
    assert
      .dom(".ai-discovery-sources__all-results")
      .hasAttribute(
        "href",
        "/search?q=miyazaki",
        "full search keeps the active query"
      );
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
    this.currentUser.ai_enabled_agents = [{ id: -34, username: "discobot" }];
    this.siteSettings.ai_discover_agent = "-34";
    sinon.stub(Topic, "find").resolves({ id: 321 });

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
    await click(".ai-search-discoveries__continue-conversation button");

    assert.strictEqual(
      submittedBody.get("request_id"),
      "13e16948-6a2a-42f4-80b4-5acac1f74713"
    );
    assert.false(submittedBody.has("query"));
    assert.false(submittedBody.has("context"));
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
