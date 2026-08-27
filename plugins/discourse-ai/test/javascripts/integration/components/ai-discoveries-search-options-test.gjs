import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AiDiscoveriesSearchOptions from "discourse/plugins/discourse-ai/discourse/components/ai-discoveries-search-options";

module(
  "Integration | Component | AiDiscoveriesSearchOptions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.triggeredQueries = [];
      this.dismissals = 0;
      const testContext = this;

      this.owner.register(
        "service:discobot-discoveries",
        class extends Service {
          @tracked lastQuery = "";
          @tracked mode = "ask";

          setMode(mode) {
            this.mode = mode;
          }

          triggerDiscovery(query) {
            this.lastQuery = query;
            testContext.triggeredQueries.push(query);
          }

          dismissDiscovery() {
            this.lastQuery = "";
            testContext.dismissals++;
          }
        }
      );

      this.owner.lookup("service:search").activeGlobalSearchTerm = "miyazaki";

      this.filters = [];
      this.searches = 0;
      this.termChanges = [];
      this.contextClears = 0;
      this.clearTopicContext = () => this.contextClears++;
      this.updateTypeFilter = (value) => this.filters.push(value);
      this.triggerSearch = () => this.searches++;
      // core's action updates the term as well as running the search, and the
      // options read their state off it
      this.searchTermChanged = (term, opts) => {
        this.termChanges.push({ term, opts });
        this.owner.lookup("service:search").activeGlobalSearchTerm = term;
      };
    });

    test("offers both ways to resolve the term, without repeating it", async function (assert) {
      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .exists("the indexed search is offered");
      assert
        .dom(".ai-discoveries-search-options__option.--ask")
        .exists("and asking sits beside it");
      assert
        .dom(".ai-discoveries-search-options__option.--ask")
        .hasClass("is-active", "Ask AI is selected by default");
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .doesNotExist("advanced search is hidden for Ask AI");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .hasText(
          i18n("discourse_ai.discobot_discoveries.search_all_topics"),
          "the indexed option names itself, not the term"
        );
      assert
        .dom(".ai-discoveries-search-options__option.--ask")
        .hasText(
          i18n("discourse_ai.discobot_discoveries.ask_ai"),
          "and so does asking"
        );
    });

    test("each option runs its own kind of search", async function (assert) {
      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      await click(".ai-discoveries-search-options__option.--search");

      assert.deepEqual(
        this.filters,
        [null],
        "searching all topics asks for topics"
      );
      assert.strictEqual(
        this.contextClears,
        1,
        "and releases any topic the menu was scoped to"
      );
      assert.strictEqual(this.searches, 1, "and runs the indexed search");
      assert.deepEqual(
        this.triggeredQueries,
        [],
        "without asking the AI anything"
      );

      await click(".ai-discoveries-search-options__option.--ask");

      assert.deepEqual(
        this.triggeredQueries,
        ["miyazaki"],
        "asking starts a discovery"
      );
      assert.strictEqual(
        this.searches,
        1,
        "and leaves the indexed search alone"
      );

      await click(".ai-discoveries-search-options__option.--search");

      assert.strictEqual(
        this.dismissals,
        2,
        "choosing the indexed results takes the answer down with it"
      );
      assert.strictEqual(
        this.owner.lookup("service:discobot-discoveries").lastQuery,
        "",
        "the term is released so the answer stops standing in for it"
      );
    });

    test("a topic page leads with its own scope", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = { type: "topic", id: 1 };

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option:first-child")
        .hasClass("--topic", "the narrowest scope is offered first");

      await click(".ai-discoveries-search-options__option.--topic");

      assert.deepEqual(
        this.termChanges,
        [
          {
            term: "miyazaki",
            opts: { searchTopics: true, setTopicContext: true },
          },
        ],
        "picking it scopes the menu to the topic and runs the search"
      );
    });

    test("marks whichever option is in effect", async function (assert) {
      this.owner.lookup("service:discobot-discoveries").setMode("search");

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @clearTopicContext={{this.clearTopicContext}}
            @searchTopics={{true}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .hasClass(
          "is-active",
          "the indexed search is what the menu is showing"
        );
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .exists("advanced search is available for all topics");

      this.owner.lookup("service:search").activeGlobalSearchTerm =
        "a different query";
      await settled();

      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .hasClass("is-active", "Search stays selected for the next query");
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .exists("advanced search remains available for the next query");

      await click(".ai-discoveries-search-options__option.--ask");

      assert
        .dom(".ai-discoveries-search-options__option.--ask")
        .hasClass("is-active", "asking takes over once it owns the term");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .doesNotHaveClass("is-active", "and the other option steps back");
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .doesNotExist("advanced search is hidden while asking AI");
    });

    test("a user page offers that user's posts", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = {
        type: "user",
        user: { username: "eviltrout" },
      };

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option:first-child")
        .hasClass("--user", "the narrower reach is offered first");

      await click(".ai-discoveries-search-options__option.--user");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki @eviltrout", opts: { searchTopics: true } }],
        "picking it puts the operator in the term, as the native shortcut does"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--user")
        .hasClass("is-active", "and it reads as the one in effect");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .doesNotHaveClass(
          "is-active",
          "the wider reach does not light up alongside it"
        );
    });

    test("widening drops the username it was narrowed by", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = {
        type: "user",
        user: { username: "eviltrout" },
      };
      searchService.activeGlobalSearchTerm = "miyazaki @eviltrout";

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      await click(".ai-discoveries-search-options__option.--search");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki", opts: { searchTopics: true } }],
        "the operator goes with the narrower reach it belonged to"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--user")
        .doesNotHaveClass(
          "is-active",
          "so that option stops reading as active"
        );
    });

    test("recognises a username already in the term", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = {
        type: "user",
        user: { username: "eviltrout" },
      };
      searchService.activeGlobalSearchTerm = "miyazaki @eviltrout";

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--user")
        .hasClass("is-active", "the operator in the term is what marks it");

      await click(".ai-discoveries-search-options__option.--user");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki @eviltrout", opts: { searchTopics: true } }],
        "picking it again runs the same term rather than repeating the operator"
      );
    });

    test("does not mistake a longer username for this one", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = {
        type: "user",
        user: { username: "evil" },
      };
      searchService.activeGlobalSearchTerm = "miyazaki @eviltrout";

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--user")
        .doesNotHaveClass("is-active", "@eviltrout is not @evil");
    });

    test("a message inbox offers its messages", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = { type: "private_messages" };

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--messages")
        .doesNotHaveClass(
          "is-active",
          "the inbox is not scoped until the menu says so"
        );

      await click(".ai-discoveries-search-options__option.--messages");

      assert.deepEqual(
        this.termChanges,
        [
          {
            term: "miyazaki",
            opts: { searchTopics: true, setPMInboxContext: true },
          },
        ],
        "picking it scopes the menu to the inbox"
      );
    });

    test("reads the inbox scope off the menu", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = { type: "private_messages" };

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
            @inPMInboxContext={{true}}
            @searchTopics={{true}}
          />
        </template>
      );

      assert
        .dom(".ai-discoveries-search-options__option.--messages")
        .hasClass("is-active", "a menu already scoped to the inbox says so");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .doesNotHaveClass(
          "is-active",
          "and the wider reach does not light up with it"
        );
    });

    test("stays out of the menu with an empty box", async function (assert) {
      this.owner.lookup("service:search").activeGlobalSearchTerm = "";

      await render(<template><AiDiscoveriesSearchOptions /></template>);

      assert
        .dom(".ai-discoveries-search-options")
        .doesNotExist("there is no term to resolve");
    });
  }
);
