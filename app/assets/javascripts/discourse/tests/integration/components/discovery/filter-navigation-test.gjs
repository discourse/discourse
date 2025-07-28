import {
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterNavigation from "discourse/components/discovery/filter-navigation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | discovery | filter-navigation",
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
        { name: "status:", description: "Filter status", priority: 1 },
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
      await render(
        <template>
          <FilterNavigation
            @tips={{this.tips}}
            @queryString={{this.query}}
            @updateQueryString={{this.update}}
          />
        </template>
      );

      await triggerEvent("#queryStringInput", "focus");
      assert
        .dom(".filter-navigation__tip-button")
        .exists({ count: 3 }, "tips appear");

      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      assert
        .dom(
          ".filter-navigation__tip-button--selected .filter-navigation__tip-name"
        )
        .hasText("category:");

      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      assert
        .dom(
          ".filter-navigation__tip-button--selected .filter-navigation__tip-name"
        )
        .hasText("tag:");

      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowUp");
      assert
        .dom(
          ".filter-navigation__tip-button--selected .filter-navigation__tip-name"
        )
        .hasText("category:");
    });

    /* selecting a tip ------------------------------------------------------- */
    test("selecting a tip with Tab", async function (assert) {
      await render(
        <template>
          <FilterNavigation
            @tips={{this.tips}}
            @queryString={{this.query}}
            @updateQueryString={{this.update}}
          />
        </template>
      );

      await triggerEvent("#queryStringInput", "focus");
      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      await triggerKeyEvent("#queryStringInput", "keydown", "Tab");

      assert.strictEqual(this.query, "category:", "category filter added");

      await triggerKeyEvent("#queryStringInput", "keydown", "Tab");
      assert
        .dom("#queryStringInput")
        .hasValue("category:bugs ", "category value selected");
    });

    test("searching tag values", async function (assert) {
      await render(
        <template>
          <FilterNavigation
            @tips={{this.tips}}
            @queryString={{this.query}}
            @updateQueryString={{this.update}}
          />
        </template>
      );

      await triggerEvent("#queryStringInput", "focus");
      await fillIn("#queryStringInput", "tag:e");

      assert
        .dom(".filter-navigation__tip-button")
        .exists("tag search results shown");
      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      await triggerKeyEvent("#queryStringInput", "keydown", "Enter");

      assert.strictEqual(this.query, "tag:ember", "tag result selected");
    });

    test("escape hides suggestions", async function (assert) {
      await render(
        <template>
          <FilterNavigation
            @tips={{this.tips}}
            @queryString={{this.query}}
            @updateQueryString={{this.update}}
            @blockEnterSubmit={{this.blockEnter}}
          />
        </template>
      );

      await triggerEvent("#queryStringInput", "focus");
      assert
        .dom(".filter-navigation__tip-button")
        .exists("tips visible after focus");

      await triggerKeyEvent("#queryStringInput", "keydown", "Escape");
      assert
        .dom(".filter-navigation__tip-button")
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
          <FilterNavigation
            @tips={{this.tips}}
            @queryString={{this.query}}
            @updateQueryString={{this.update}}
            @blockEnterSubmit={{this.blockEnter}}
          />
        </template>
      );

      await triggerEvent("#queryStringInput", "focus");
      await fillIn("#queryStringInput", "cat");

      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      await triggerKeyEvent("#queryStringInput", "keydown", "ArrowDown");
      await triggerKeyEvent("#queryStringInput", "keydown", "Tab");

      assert
        .dom("#queryStringInput")
        .hasValue("-category:", "negative prefix applied");
    });
  }
);
