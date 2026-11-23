import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterNavigationBuilder from "discourse/components/discovery/filter-navigation-builder";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Discovery | FilterNavigationBuilder",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.tips = [
        { name: "category:", description: "Filter category", priority: 1 },
        { name: "status:", description: "Filter status", priority: 1 },
        { name: "status:open", description: "Open topics" },
        { name: "status:closed", description: "Closed topics" },
        { name: "created-after:", description: "Created after", type: "date" },
      ];
      this.changes = [];
      this.onChange = (value, refresh) => this.changes.push([value, refresh]);
    });

    test("lists only filter names in the add menu", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue=""
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      assert
        .dom(".filter-navigation-builder__add")
        .hasText("Add filter", "labelled while there are no filters")
        .hasClass("btn-icon-text")
        .doesNotHaveClass("no-text");

      await click(".filter-navigation-builder__add");

      assert
        .dom(".filter-navigation-builder__menu .filter-navigation__tip-item")
        .exists({ count: 3 });

      await fillIn(".filter-navigation-builder__menu-search", "stat");
      assert
        .dom(".filter-navigation-builder__menu .filter-navigation__tip-item")
        .exists({ count: 1 })
        .hasAttribute("data-filter", "status:");
    });

    test("the add button regains its label when the last chip is removed", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue="status:open"
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      assert.dom(".filter-navigation-builder__add").hasClass("no-text");

      await click(".filter-navigation-token__remove");

      assert
        .dom(".filter-navigation-builder__add")
        .hasText("Add filter")
        .hasClass("btn-icon-text")
        .doesNotHaveClass("no-text")
        .doesNotHaveClass("btn-icon");
    });

    test("orders the most used filters first", async function (assert) {
      this.tips = [
        { name: "views-min:", type: "number" },
        { name: "assigned:", priority: 1 },
        { name: "users:", priority: 1 },
        { name: "status:", priority: 1 },
        { name: "group:" },
        { name: "tag:", priority: 1 },
        { name: "category:", priority: 1 },
        { name: "zebra:" },
      ];

      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue=""
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(".filter-navigation-builder__add");

      const order = [
        ...document.querySelectorAll(
          ".filter-navigation-builder__menu .filter-navigation__tip-item"
        ),
      ].map((el) => el.dataset.filter);

      assert.deepEqual(order, [
        "category:",
        "tag:",
        "group:",
        "users:",
        "status:",
        "views-min:",
        "assigned:",
        "zebra:",
      ]);
    });

    test("choosing a filter and a value adds a token", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue="category:bugs"
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(".filter-navigation-builder__add");
      await click(
        ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='status:']"
      );

      assert
        .dom(".filter-navigation-builder__menu")
        .doesNotExist("the list of filters gives way to its values");
      assert
        .dom(".filter-navigation-token__editor-input")
        .isFocused("the values open in the same menu");

      await click(
        ".filter-navigation-token__editor .filter-navigation__tip-item"
      );

      assert.dom(".filter-navigation-token[data-token='status:open']").exists();
      assert.deepEqual(this.changes.at(-1), [
        "category:bugs status:open",
        true,
      ]);
      assert
        .dom(".filter-navigation-builder__add")
        .hasText("", "just an icon once filters are applied")
        .hasClass("no-text")
        .hasClass("btn-icon")
        .doesNotHaveClass("btn-icon-text");
    });

    test("back returns to the list of filters", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue=""
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(".filter-navigation-builder__add");
      await click(
        ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='status:']"
      );
      await click(".filter-navigation-token__editor-back");

      assert.dom(".filter-navigation-token__editor").doesNotExist();
      assert.dom(".filter-navigation-builder__menu-search").isFocused();
    });

    test("closing the menu before picking a value adds nothing", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue=""
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(".filter-navigation-builder__add");
      await click(
        ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='status:']"
      );
      await triggerKeyEvent(
        ".filter-navigation-token__editor-input",
        "keydown",
        "Escape"
      );

      assert.dom(".filter-navigation-token__editor").doesNotExist();
      assert.dom(".filter-navigation-token").doesNotExist();
      assert.deepEqual(this.changes, [], "nothing was submitted");
      assert.dom(".filter-navigation-builder__add").hasClass("btn-icon-text");
    });

    test("edit as text", async function (assert) {
      let editAsText = false;
      const onEditAsText = () => (editAsText = true);

      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue="category:bugs status:open"
            @onChange={{this.onChange}}
            @onEditAsText={{onEditAsText}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(".filter-navigation-builder__add");
      await click(".filter-navigation-builder__edit-as-text .btn");
      assert.true(editAsText);
    });
    test("number and date filters get literal labels", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue="likes-min:5 views-max:1 created-after:7 activity-before:0 latest-post-after:2026-01-15 created-before:soon"
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
        </template>
      );

      const label = (token) =>
        `.filter-navigation-token[data-token='${token}'] .filter-navigation-token__value`;

      assert.dom(label("likes-min:5")).hasText("At least 5 likes");
      assert.dom(label("views-max:1")).hasText("At most 1 view");
      assert
        .dom(label("created-after:7"))
        .hasText("Created in the last 7 days");
      assert.dom(label("activity-before:0")).hasText("No activity today");
      assert
        .dom(label("latest-post-after:2026-01-15"))
        .includesText("Posted since Jan 15, 2026");
      assert
        .dom(label("created-before:soon"))
        .hasText("soon", "unparseable values fall back to the raw value");
    });
    test("date filters take a number of days", async function (assert) {
      await render(
        <template>
          <FilterNavigationBuilder
            @initialInputValue="created-after:7"
            @onChange={{this.onChange}}
            @tips={{this.tips}}
          />
          <DMenus />
        </template>
      );

      await click(
        ".filter-navigation-token[data-filter='created-after'] .filter-navigation-token__value"
      );

      assert
        .dom(".filter-navigation-token__custom-days-input")
        .hasValue("7")
        .isFocused();
      assert
        .dom(".filter-navigation-token__days-hint")
        .hasText("Created in the last 7 days");

      await fillIn(".filter-navigation-token__custom-days-input", "14");
      assert
        .dom(".filter-navigation-token__days-hint")
        .hasText("Created in the last 14 days", "the hint follows the input");

      await triggerKeyEvent(
        ".filter-navigation-token__custom-days-input",
        "keydown",
        "Enter"
      );
      assert.deepEqual(this.changes.at(-1), ["created-after:14", true]);
    });
    module("category subcategories", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        const store = this.owner.lookup("service:store");
        const site = this.owner.lookup("service:site");
        site.categories = [
          store.createRecord("category", { id: 1, name: "Bugs", slug: "bugs" }),
          store.createRecord("category", {
            id: 2,
            name: "UX bugs",
            slug: "ux-bugs",
            parent_category_id: 1,
          }),
          store.createRecord("category", {
            id: 3,
            name: "Perf bugs",
            slug: "perf-bugs",
            parent_category_id: 1,
          }),
          store.createRecord("category", {
            id: 4,
            name: "Ideas",
            slug: "ideas",
          }),
        ];
        this.tips = [{ name: "category:", type: "category", priority: 1 }];
      });

      test("an excluded-subcategories filter reads as only", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="=category:bugs"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
          </template>
        );

        const chip = ".filter-navigation-token[data-token='=category:bugs']";
        assert
          .dom(`${chip} .filter-navigation-token__value`)
          .hasText("Bugs only");
        assert
          .dom(`${chip} a`)
          .doesNotExist("badges never link away from the filter");
        assert.dom(`${chip} .filter-navigation-token__prefix`).doesNotExist();
      });

      test("an exclude subcategories option sits under the parent", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="-category:ideas"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(
          ".filter-navigation-token[data-filter='category'] .filter-navigation-token__value"
        );

        const items = [
          ...document.querySelectorAll(
            ".filter-navigation-token__editor .filter-navigation__tip-item"
          ),
        ];
        const bugsIndex = items.findIndex(
          (el) => el.textContent.trim() === "Bugs"
        );
        assert
          .dom(items[bugsIndex + 1])
          .hasClass("--exclude-subcategories")
          .hasClass("--level-1")
          .hasText("Exclude subcategories");
        assert
          .dom(".filter-navigation__tip-item.--exclude-subcategories")
          .exists({ count: 1 }, "only categories with subcategories get one");
        assert
          .dom(".filter-navigation-token__editor a[href]")
          .doesNotExist("picker rows never link to category pages");

        await click(items[bugsIndex + 1]);
        assert.deepEqual(
          this.changes.at(-1),
          ["-=category:bugs", true],
          "keeps the exclude prefix and limits to the parent"
        );
      });

      test("picking the parent includes subcategories again", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="=category:bugs"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(
          ".filter-navigation-token[data-filter='category'] .filter-navigation-token__value"
        );
        const bugs = [
          ...document.querySelectorAll(
            ".filter-navigation-token__editor .filter-navigation__tip-item"
          ),
        ].find((el) => el.textContent.trim() === "Bugs");
        await click(bugs);

        assert.deepEqual(this.changes.at(-1), ["category:bugs", true]);
      });

      test("picking a subcategory filters to just that subcategory", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="category:ideas"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(
          ".filter-navigation-token[data-filter='category'] .filter-navigation-token__value"
        );

        const items = [
          ...document.querySelectorAll(
            ".filter-navigation-token__editor .filter-navigation__tip-item"
          ),
        ];
        const uxIndex = items.findIndex((el) =>
          el.textContent.includes("UX bugs")
        );
        assert
          .dom(items[uxIndex - 2])
          .hasText("Bugs", "subcategories follow their parent");
        assert.dom(items[uxIndex]).hasClass("--level-1", "and are indented");

        await click(items[uxIndex]);
        assert.deepEqual(
          this.changes.at(-1),
          ["category:bugs:ux-bugs", true],
          "the parent path keeps the slug unambiguous"
        );
      });

      test("a subcategory chip shows the subcategory", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="category:bugs:ux-bugs"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
          </template>
        );

        const chip = ".filter-navigation-token[data-filter='category']";
        assert
          .dom(`${chip} .filter-navigation-token__value`)
          .includesText("UX bugs");
      });
      test("categories covered by another filter are not offered again", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="category:bugs"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(".filter-navigation-builder__add");
        await click(
          ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='category:']"
        );

        const names = () =>
          [
            ...document.querySelectorAll(
              ".filter-navigation-token__editor .filter-navigation__tip-item"
            ),
          ].map((el) => el.textContent.trim());

        assert.deepEqual(
          names(),
          ["Ideas"],
          "Bugs and its subcategories are already included"
        );
      });

      test("an only filter still offers its subcategories", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="=category:bugs"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(".filter-navigation-builder__add");
        await click(
          ".filter-navigation-builder__menu .filter-navigation__tip-item[data-filter='category:']"
        );

        assert
          .dom(".filter-navigation-token__editor .filter-navigation__tip-item")
          .exists(
            { count: 5 },
            "Bugs, its exclude row, both subcategories and Ideas"
          );
      });

      test("exclude filters can still pick covered subcategories", async function (assert) {
        await render(
          <template>
            <FilterNavigationBuilder
              @initialInputValue="category:bugs -category:ideas"
              @onChange={{this.onChange}}
              @tips={{this.tips}}
            />
            <DMenus />
          </template>
        );

        await click(
          ".filter-navigation-token[data-token='-category:ideas'] .filter-navigation-token__value"
        );

        const uxBugs = [
          ...document.querySelectorAll(
            ".filter-navigation-token__editor .filter-navigation__tip-item"
          ),
        ].find((el) => el.textContent.trim() === "UX bugs");
        assert.dom(uxBugs).exists();

        await click(uxBugs);
        assert.deepEqual(this.changes.at(-1), [
          "category:bugs -category:bugs:ux-bugs",
          true,
        ]);
      });
    });
  }
);
