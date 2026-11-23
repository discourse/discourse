import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | Discovery | FilterNavigationMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    let query;
    const update = (val) => (query.value = val);

    hooks.beforeEach(function () {
      this.tips = [
        {
          name: "category:",
          description: "Filter category",
          priority: 1,
          type: "category",
        },
        { name: "status:", description: "Filter status", priority: 1 },
        {
          name: "tag:",
          description: "Filter tag",
          priority: 1,
          type: "tag",
          delimiters: [
            { name: "+", description: "intersect" },
            { name: ",", description: "add" },
          ],
        },
        { name: "status:open", description: "Open topics" },
      ];

      query = tracked("");

      this.site = this.owner.lookup("service:site");
      const store = this.owner.lookup("service:store");
      this.site.categories = [
        store.createRecord("category", { id: 1, name: "Bug", slug: "bugs" }),
        store.createRecord("category", {
          id: 2,
          name: "Feature",
          slug: "feature",
        }),
      ];

      pretender.get("/tags/filter/search.json", () =>
        response({ results: [{ name: "ember", count: 1 }] })
      );
      pretender.get("/u/search/users.json", () => response({ users: [] }));
    });

    test("keyboard navigation through tips", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialFilterQueryString={{query.value}}
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      assert
        .dom(".filter-navigation__tip-item")
        .exists({ count: 3 }, "tips appear");

      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      assert
        .dom(
          ".filter-navigation__tip-item.--selected .filter-navigation__tip-name"
        )
        .hasText("category:");

      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      assert
        .dom(
          ".filter-navigation__tip-item.--selected .filter-navigation__tip-name"
        )
        .hasText("status:");

      await triggerKeyEvent("#topic-query-filter-input", "keydown", "ArrowUp");
      assert
        .dom(
          ".filter-navigation__tip-item.--selected .filter-navigation__tip-name"
        )
        .hasText("category:");
    });

    test("selecting a tip with Tab", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialFilterQueryString={{query.value}}
            @onChange={{update}}
            @tips={{this.tips}}
          />

          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Tab");
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Enter");

      assert.strictEqual(query.value, "category:", "category filter added");

      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Tab");
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Enter");
      assert
        .dom("#topic-query-filter-input")
        .hasValue("", "input is cleared once the value is selected");
      assert
        .dom(".filter-navigation-token[data-filter='category']")
        .exists("category value becomes a token");
      assert.strictEqual(query.value, "category:bugs");
    });

    test("searching tag values", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialFilterQueryString={{query.value}}
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      await fillIn("#topic-query-filter-input", "tag:e");

      // IDK why this is needed, the same thing works if you do it manually in the UI.
      await triggerEvent("#topic-query-filter-input", "blur");
      await triggerEvent("#topic-query-filter-input", "focus");

      assert
        .dom(".filter-navigation__tip-item")
        .exists("tag search results shown");

      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Enter");

      assert.strictEqual(query.value, "tag:ember", "tag result selected");
      assert
        .dom(".filter-navigation-token[data-token='tag:ember']")
        .exists("a multi-value filter's chosen value becomes a token");
      assert.dom("#topic-query-filter-input").hasValue("");
    });

    test("escape hides suggestions", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialFilterQueryString={{query.value}}
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      assert
        .dom(".filter-navigation__tip-item")
        .exists({ count: 3 }, "tips visible after focus");

      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Escape");
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Escape");
      assert
        .dom(".filter-navigation__tip-item")
        .doesNotExist("tips hidden after escape");
    });

    test("prefix support for categories", async function (assert) {
      this.tips = [
        {
          name: "category:",
          description: "Filter category",
          priority: 1,
          type: "category",
          prefixes: [
            { name: "-", description: "Exclude category" },
            { name: "=", description: "Category without subcategories" },
          ],
        },
      ];

      await render(
        <template>
          <FilterNavigationMenu
            @initialFilterQueryString={{query.value}}
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      await fillIn("#topic-query-filter-input", "cat");

      assert
        .dom(".filter-navigation__tip-item")
        .exists("category search results shown");

      assert
        .dom(".filter-navigation__tip-item")
        .exists(".badge-category__wrapper", "category badge HTML shown");

      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "ArrowDown"
      );
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Tab");

      assert
        .dom("#topic-query-filter-input")
        .hasValue("-category:", "negative prefix applied");
    });
    test("renders the initial query as tokens", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialInputValue="category:bugs -tag:ember hello"
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      assert.dom(".filter-navigation-token").exists({ count: 3 });
      assert
        .dom(
          ".filter-navigation-token[data-filter='tag'] .filter-navigation-token__prefix"
        )
        .hasText("-");
      assert
        .dom(".filter-navigation-token.--text")
        .includesText("hello", "free text renders as a plain token");
      assert.dom("#topic-query-filter-input").hasValue("");
    });

    test("typing a space turns the segment into a token", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialInputValue=""
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await fillIn("#topic-query-filter-input", "status:open ");

      assert
        .dom(".filter-navigation-token[data-filter='status']")
        .exists("segment committed as a token");
      assert.dom("#topic-query-filter-input").hasValue("");
      assert.strictEqual(query.value, "status:open");
    });

    test("removing a token", async function (assert) {
      const changes = [];
      const onChange = (value, refresh) => changes.push([value, refresh]);

      await render(
        <template>
          <FilterNavigationMenu
            @initialInputValue="category:bugs status:open"
            @onChange={{onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(
        ".filter-navigation-token[data-filter='category'] .filter-navigation-token__remove"
      );

      assert.dom(".filter-navigation-token").exists({ count: 1 });
      assert.deepEqual(
        changes.at(-1),
        ["status:open", true],
        "the remaining query is submitted"
      );
    });

    test("backspace in an empty input edits the last token", async function (assert) {
      await render(
        <template>
          <FilterNavigationMenu
            @initialInputValue="category:bugs status:open"
            @onChange={{update}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerKeyEvent(
        "#topic-query-filter-input",
        "keydown",
        "Backspace"
      );

      assert.dom(".filter-navigation-token").exists({ count: 1 });
      assert.dom("#topic-query-filter-input").hasValue("status:open");
    });

    test("changing a token's value from its dropdown", async function (assert) {
      const changes = [];
      const onChange = (value, refresh) => changes.push([value, refresh]);

      await render(
        <template>
          <FilterNavigationMenu
            @initialInputValue="category:bugs status:open"
            @onChange={{onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await triggerEvent("#topic-query-filter-input", "focus");
      assert
        .dom("[data-identifier='filter-navigation-menu-list']")
        .exists("autocomplete is open");

      await click(
        ".filter-navigation-token[data-filter='category'] .filter-navigation-token__value"
      );
      assert
        .dom("[data-identifier='filter-navigation-menu-list']")
        .doesNotExist("opening a token editor closes the autocomplete");

      await fillIn(".filter-navigation-token__editor-input", "feat");
      await click(
        ".filter-navigation-token__editor .filter-navigation__tip-item"
      );

      assert.deepEqual(
        changes.at(-1),
        ["category:feature status:open", true],
        "the token is replaced in place and the query submitted"
      );
    });
  }
);
