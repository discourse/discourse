import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import AiSearchDiscoveries from "discourse/plugins/discourse-ai/discourse/components/ai-search-discoveries";

module("Integration | Component | ai-search-discoveries", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.ai_discover_enabled = true;
    this.currentUser.can_use_ai_discover_persona = true;

    this.closeSearchMenuCalled = false;
    this.closeSearchMenu = () => {
      this.closeSearchMenuCalled = true;
    };

    sinon.stub(DiscourseURL, "routeTo");
  });

  hooks.afterEach(function () {
    sinon.restore();
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
});
