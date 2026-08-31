import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiDiscobotDiscoveries from "discourse/plugins/discourse-ai/discourse/connectors/search-menu-results-top/ai-discobot-discoveries";

module("Integration | Component | AiDiscobotDiscoveries", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.triggeredQueries = [];
    this.creditsAvailable = true;
    const testContext = this;

    this.owner.register(
      "service:ai-credits",
      class extends Service {
        async isFeatureCreditAvailable() {
          return testContext.creditsAvailable;
        }
      }
    );

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        @tracked loadingDiscoveries = false;
        @tracked isStreaming = true;
        @tracked lastQuery = "";
        @tracked sources = [];
        @tracked answerable = null;

        streamedText = "";
        discoveryTimedOut = false;
        showDiscoveryTitle = true;

        triggerDiscovery(query) {
          testContext.triggeredQueries.push(query);
        }

        onDiscoveryUpdate() {}
      }
    );

    this.discobotDiscoveries = this.owner.lookup(
      "service:discobot-discoveries"
    );
    this.outletArgs = { searchTerm: "miyazaki" };
  });

  test("waits for the search term to be submitted", async function (assert) {
    await render(
      <template>
        <AiDiscobotDiscoveries @outletArgs={{this.outletArgs}} />
      </template>
    );

    assert
      .dom(".ai-discobot-discoveries")
      .doesNotExist("typing alone does not show a Discoveries result");
    assert.deepEqual(
      this.triggeredQueries,
      [],
      "typing alone does not start an AI request"
    );
  });

  test("keeps the answer surface mounted when credits are unavailable", async function (assert) {
    this.creditsAvailable = false;
    this.discobotDiscoveries.lastQuery = "miyazaki";

    await render(
      <template>
        <AiDiscobotDiscoveries @outletArgs={{this.outletArgs}} />
      </template>
    );

    assert
      .dom(".ai-search-discoveries")
      .exists("the server credit error has a subscribed surface to render in");
  });

  // Whether the indexed list renders is decided by the search-menu transformers,
  // covered in acceptance/ai-search-discoveries-test.js. This holds the states
  // the connector reports for it.
  test("reports its progress for a submitted Discoveries search", async function (assert) {
    this.discobotDiscoveries.lastQuery = "miyazaki";

    await render(
      <template>
        <AiDiscobotDiscoveries @outletArgs={{this.outletArgs}} />
        <div class="no-results">No results found</div>
      </template>
    );

    assert
      .dom(".ai-discobot-discoveries")
      .hasClass("is-generating", "the connector exposes its generating state");
    assert.deepEqual(
      this.triggeredQueries,
      [],
      "mounting the submitted result does not duplicate the request"
    );

    this.discobotDiscoveries.isStreaming = false;
    this.discobotDiscoveries.answerable = false;
    await settled();

    assert
      .dom(".ai-discobot-discoveries")
      .hasClass("has-no-answer", "the connector reports it cannot answer");
    assert
      .dom(".no-results")
      .isNotVisible("the redundant native no-results message stays hidden");

    this.discobotDiscoveries.sources = [
      { title: "A selected source", url: "/t/source/1" },
    ];
    await settled();

    assert
      .dom(".ai-discobot-discoveries")
      .doesNotHaveClass(
        "is-generating",
        "the generating state ends with the AI call"
      );
    assert
      .dom(".ai-discobot-discoveries")
      .hasClass("has-sources", "the connector reports its selected sources");
  });

  test("uses the native welcome search results surface", async function (assert) {
    this.discobotDiscoveries.lastQuery = "miyazaki";
    this.discobotDiscoveries.isStreaming = false;
    this.discobotDiscoveries.sources = [
      { title: "A selected source", url: "/t/source/1" },
    ];

    await render(
      <template>
        <div class="search-menu welcome-banner__search-menu">
          <div class="results">
            <AiDiscobotDiscoveries @outletArgs={{this.outletArgs}} />
          </div>
        </div>
      </template>
    );

    const styles = getComputedStyle(find(".ai-discobot-discoveries"));

    assert.strictEqual(
      styles.marginBlockStart,
      "0px",
      "Discoveries does not sit inside a second offset panel"
    );
    assert.strictEqual(
      styles.borderTopWidth,
      "0px",
      "the native search panel owns the visible border"
    );
  });
});
