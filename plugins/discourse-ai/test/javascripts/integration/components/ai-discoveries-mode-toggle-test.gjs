import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchMenu from "discourse/components/search-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiDiscoveriesModeToggle from "discourse/plugins/discourse-ai/discourse/components/ai-discoveries-mode-toggle";
import AiDiscoveriesModeToggleConnector from "discourse/plugins/discourse-ai/discourse/connectors/search-menu-after-input/ai-discoveries-mode-toggle";

module("Integration | Component | AiDiscoveriesModeToggle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.triggeredQueries = [];
    const testContext = this;

    this.owner.register(
      "service:discobot-discoveries",
      class extends Service {
        @tracked mode = "ask";
        lastQuery = "";

        setMode(mode) {
          this.mode = mode;
        }

        triggerDiscovery(query) {
          if (this.lastQuery === query) {
            return;
          }

          this.lastQuery = query;
          testContext.triggeredQueries.push(query);
        }
      }
    );

    this.owner.lookup("service:search").activeGlobalSearchTerm = "miyazaki";
  });

  test("defaults to Ask and allows switching search modes", async function (assert) {
    this.searchSubmissions = 0;
    this.submitSearch = () => this.searchSubmissions++;

    await render(
      <template>
        <AiDiscoveriesModeToggle @submitSearch={{this.submitSearch}} />
      </template>
    );

    assert
      .dom(".ai-discoveries-mode .d-segmented-control")
      .exists("the search modes use the shared segmented control");
    assert
      .dom('.ai-discoveries-mode input[value="ask"]')
      .isChecked("Ask is selected by default");

    await click(".ai-discoveries-mode__option.--search");

    assert
      .dom('.ai-discoveries-mode input[value="search"]')
      .isChecked("Search can be selected");
    assert.deepEqual(
      this.triggeredQueries,
      [],
      "selecting Search does not start a discovery"
    );

    await click(".ai-discoveries-mode__option.--ask");

    assert.deepEqual(
      this.triggeredQueries,
      [],
      "selecting Ask waits for an explicit submission"
    );

    await click(".ai-discoveries-mode__submit");

    assert.deepEqual(
      this.triggeredQueries,
      ["miyazaki"],
      "the AI submit button starts a discovery"
    );

    await click(".ai-discoveries-mode__option.--search");
    await click(".ai-discoveries-mode__submit");

    assert.strictEqual(
      this.searchSubmissions,
      1,
      "the same submit control runs normal search in Search mode"
    );
  });

  test("hides indexed search tips in Ask mode", async function (assert) {
    await render(
      <template>
        <div class="search-menu welcome-banner__search-menu">
          <a class="search-icon">Open advanced search</a>
          <div class="search-menu-container">
            <div class="search-input-wrapper">
              <div class="search-input search-input--welcome-banner"></div>
              <AiDiscoveriesModeToggle />
            </div>
            <div class="search-random-quick-tip">Search tip</div>
          </div>
        </div>
      </template>
    );

    assert
      .dom(".search-random-quick-tip")
      .isNotVisible("the indexed search tip is hidden in Ask mode");
    assert
      .dom(".welcome-banner__search-menu > .search-icon")
      .isNotVisible("the separate advanced search link is hidden");

    await click(".ai-discoveries-mode__option.--search");

    assert
      .dom(".search-random-quick-tip")
      .isVisible("the indexed search tip remains available in Search mode");
  });

  test("renders beside the native welcome banner search input", async function (assert) {
    this.siteSettings.ai_discover_agent = 1;
    this.siteSettings.ai_discover_enabled = true;
    this.currentUser.can_use_ai_discover_agent = true;
    this.currentUser.user_option.ai_search_discoveries = true;

    await render(
      <template>
        <SearchMenu
          @location="welcome-banner"
          @searchInputId="welcome-banner-search-input"
        />
      </template>
    );

    assert
      .dom(".search-input-wrapper > .search-input + .ai-discoveries-mode")
      .exists("the mode and submit controls do not replace the native input");
  });

  test("only renders in the welcome banner search", function (assert) {
    const context = {
      currentUser: {
        can_use_ai_discover_agent: true,
        user_option: { ai_search_discoveries: true },
      },
      siteSettings: {
        ai_discover_agent: 1,
        ai_discover_enabled: true,
      },
    };

    assert.false(
      AiDiscoveriesModeToggleConnector.shouldRender(undefined, context),
      "missing outlet arguments are safe"
    );
    assert.false(
      AiDiscoveriesModeToggleConnector.shouldRender(
        { location: "header" },
        context
      ),
      "the compact header keeps its existing experience"
    );
    assert.true(
      AiDiscoveriesModeToggleConnector.shouldRender(
        { location: "welcome-banner" },
        context
      ),
      "the control renders in the welcome banner search"
    );
  });
});
