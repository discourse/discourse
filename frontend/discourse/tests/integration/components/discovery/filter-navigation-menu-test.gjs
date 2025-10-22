import {
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DMenus from "float-kit/components/d-menus";

module(
  "Integration | Component | discovery | FilterNavigationMenu",
  function (hooks) {
    setupRenderingTest(hooks);

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

      this.query = "";
      this.update = (val) => this.set("query", val);

      this.site = this.owner.lookup("service:site");
      this.site.categories = [
        { id: 1, name: "Bug", slug: "bugs" },
        { id: 2, name: "Feature", slug: "feature" },
      ];

      pretender.get("/tags/filter/search.json", () =>
        response({ results: [{ name: "ember", count: 1 }] })
      );
      pretender.get("/u/search/users.json", () => response({ users: [] }));
    });

    test("keyboard navigation through tips", async function (assert) {
      const self = this;

      await render(
        <template>
          <FilterNavigationMenu
            @tips={{self.tips}}
            @initialFilterQueryString={{self.query}}
            @onChange={{self.update}}
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
      const self = this;

      await render(
        <template>
          <FilterNavigationMenu
            @tips={{self.tips}}
            @initialFilterQueryString={{self.query}}
            @onChange={{self.update}}
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

      assert.strictEqual(this.query, "category:", "category filter added");

      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Tab");
      await triggerKeyEvent("#topic-query-filter-input", "keydown", "Enter");
      assert
        .dom("#topic-query-filter-input")
        .hasValue("category:bugs ", "category value selected");
    });

    test("searching tag values", async function (assert) {
      const self = this;
      await render(
        <template>
          <FilterNavigationMenu
            @tips={{self.tips}}
            @initialFilterQueryString={{self.query}}
            @onChange={{self.update}}
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

      assert.strictEqual(this.query, "tag:ember", "tag result selected");
    });

    test("escape hides suggestions", async function (assert) {
      const self = this;
      await render(
        <template>
          <FilterNavigationMenu
            @tips={{self.tips}}
            @initialFilterQueryString={{self.query}}
            @onChange={{self.update}}
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
      const self = this;
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
            @tips={{self.tips}}
            @initialFilterQueryString={{self.query}}
            @onChange={{self.update}}
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
  }
);
