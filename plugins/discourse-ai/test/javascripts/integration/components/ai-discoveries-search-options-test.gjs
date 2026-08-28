import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { translateModKey } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import Tag from "discourse/models/tag";
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
          @tracked searchMode = "ask";

          selectSearchMode(mode) {
            this.searchMode = mode;
          }

          triggerDiscovery(query) {
            this.searchMode = "ask";
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
        .hasClass("is-active", "Ask AI is the first-use default");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .doesNotHaveAttribute(
          "title",
          "Search does not claim Enter while Ask AI is selected"
        );
      assert.dom(".ai-discoveries-search-options__option.--ask").hasAttribute(
        "title",
        i18n("discourse_ai.discobot_discoveries.shortcut_hint", {
          shortcut: i18n("shortcut_modifier_key.enter"),
        }),
        "the selected mode owns Enter"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .doesNotExist("advanced search waits until Search is selected");
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
      this.owner.lookup("service:discobot-discoveries").searchMode = "search";

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
        .hasClass(
          "is-active",
          "the indexed results still stand until the term is resubmitted"
        );
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

    test("a category page offers that category", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      // a real subcategory from the site, so the context is the shape the app
      // actually produces rather than one written out here
      const category = this.owner
        .lookup("service:site")
        .categories.find((candidate) => candidate.parentCategory);
      searchService.searchContext = category.searchContext;

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
        .hasClass("--category", "the narrower reach is offered first");

      await click(".ai-discoveries-search-options__option.--category");

      assert.strictEqual(
        this.termChanges[0]?.term,
        `miyazaki #${category.parentCategory.slug}:${category.slug}`,
        "a subcategory carries its parent, as the native slug does"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--category")
        .hasClass("is-active", "and it reads as the one in effect");
    });

    test("a tag page offers that tag", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = Tag.create({
        id: 1,
        name: "ruby",
      }).searchContext;

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

      await click(".ai-discoveries-search-options__option.--tag");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki #ruby", opts: { searchTopics: true } }],
        "the tag goes in the term the way the native shortcut puts it there"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--tag")
        .hasClass("is-active", "and it reads as the one in effect");
      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .doesNotHaveClass(
          "is-active",
          "the wider reach does not light up alongside it"
        );
    });

    test("a tag page inside a category offers both", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      // mirrors what `routes/tag/show.js` assembles for a tag inside a category
      searchService.searchContext = {
        type: "tagIntersection",
        tagId: "ruby",
        tag: Tag.create({ id: 1, name: "ruby" }),
        additionalTags: null,
        categoryId: 2,
        category: Category.create({ id: 2, slug: "support" }),
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
        .hasClass("--tag", "a tag inside a category reads as a tag scope");

      await click(".ai-discoveries-search-options__option.--tag");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki #ruby #support", opts: { searchTopics: true } }],
        "both operators go in, as the native shortcut puts them there"
      );
    });

    test("several tags intersect rather than repeating", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.searchContext = {
        type: "tagIntersection",
        tagId: "ruby",
        tag: Tag.create({ id: 1, name: "ruby" }),
        additionalTags: ["rails"],
        categoryId: null,
        category: null,
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

      await click(".ai-discoveries-search-options__option.--tag");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki tags:ruby+rails", opts: { searchTopics: true } }],
        "several tags use the intersection operator"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--tag")
        .hasClass("is-active", "and it reads as the one in effect");
    });

    test("asking leaves the scope it does not honour behind", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      const site = this.owner.lookup("service:site");
      const category = site.categories.find(
        (candidate) => !candidate.parentCategory
      );
      searchService.activeGlobalSearchTerm = `test #${category.slug}`;
      searchService.searchContext = category.searchContext;

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
        .dom(".ai-discoveries-search-options__option.--category")
        .hasClass("is-active", "the scope is what is in effect to begin with");

      await click(".ai-discoveries-search-options__option.--ask");

      assert.strictEqual(
        this.termChanges.at(-1)?.term,
        "test",
        "the operator is taken out rather than asked as part of the question"
      );
      assert.deepEqual(
        this.triggeredQueries,
        ["test"],
        "and the model is asked the question without it"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--category")
        .doesNotHaveClass(
          "is-active",
          "so the scope stops reading as the one in effect"
        );
    });

    test("a scope is not offered on top of a modifier already in the term", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      const site = this.owner.lookup("service:site");
      const [first, second] = site.categories.filter(
        (candidate) => !candidate.parentCategory
      );
      // the reader moved here from another category without clearing the box
      searchService.activeGlobalSearchTerm = `miyazaki #${first.slug}`;
      searchService.searchContext = second.searchContext;

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
        .dom(".ai-discoveries-search-options__option.--category")
        .doesNotExist(
          "the page arrived at is not stacked onto the page left behind"
        );

      searchService.activeGlobalSearchTerm = `miyazaki #${second.slug}`;
      await settled();

      assert
        .dom(".ai-discoveries-search-options__option.--category")
        .hasClass(
          "is-active",
          "but it stays while the modifier in the term is its own"
        );
    });

    test("widening drops every operator it was narrowed by", async function (assert) {
      const searchService = this.owner.lookup("service:search");
      searchService.activeGlobalSearchTerm = "miyazaki #ruby #support";
      // mirrors what `routes/tag/show.js` assembles for a tag inside a category
      searchService.searchContext = {
        type: "tagIntersection",
        tagId: "ruby",
        tag: Tag.create({ id: 1, name: "ruby" }),
        additionalTags: null,
        categoryId: 2,
        category: Category.create({ id: 2, slug: "support" }),
      };

      await render(
        <template>
          <AiDiscoveriesSearchOptions
            @triggerSearch={{this.triggerSearch}}
            @updateTypeFilter={{this.updateTypeFilter}}
            @searchTermChanged={{this.searchTermChanged}}
            @clearTopicContext={{this.clearTopicContext}}
            @searchTopics={{true}}
          />
        </template>
      );

      await click(".ai-discoveries-search-options__option.--search");

      assert.deepEqual(
        this.termChanges,
        [{ term: "miyazaki", opts: { searchTopics: true } }],
        "the wider reach leaves neither behind"
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

      // A sloppier match would read @eviltrout as this context's own operator
      // and offer the option as the one in effect; a correct one sees a
      // modifier belonging to something else and withholds it.
      assert
        .dom(".ai-discoveries-search-options__option.--user")
        .doesNotExist("@eviltrout is not @evil");
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

    test("the options that have a shortcut say so", async function (assert) {
      this.owner.lookup("service:discobot-discoveries").searchMode = "search";

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

      const shortcut = (...keys) =>
        keys
          .map((key) =>
            key === "meta"
              ? translateModKey("Meta")
              : i18n(`shortcut_modifier_key.${key}`)
          )
          .join(" + ");

      const hint = (...keys) =>
        i18n("discourse_ai.discobot_discoveries.shortcut_hint", {
          shortcut: shortcut(...keys),
        });

      assert
        .dom(".ai-discoveries-search-options__option.--search")
        .hasAttribute(
          "title",
          hint("enter"),
          "the indexed search names the key that runs it"
        );
      assert.dom(".ai-discoveries-search-options__option.--ask").hasAttribute(
        "title",
        // spelled out rather than composed, so the format itself is pinned:
        // nothing here depends on the platform
        "or Shift + Enter",
        "and asking names its own"
      );
      assert
        .dom(".ai-discoveries-search-options__option.--advanced")
        .hasAttribute(
          "title",
          i18n("discourse_ai.discobot_discoveries.advanced_with_shortcut", {
            shortcut: hint("meta", "enter"),
          }),
          "advanced search keeps its purpose, having no label of its own"
        );
      assert
        .dom(".ai-discoveries-search-options__option.--topic")
        .doesNotExist(
          "and a scope, which has no keybinding, is not offered here"
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
