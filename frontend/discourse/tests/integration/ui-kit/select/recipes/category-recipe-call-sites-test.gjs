import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SiteSettingCategoryList from "discourse/admin/components/site-settings/category-list";
import BreadCrumbs from "discourse/components/bread-crumbs";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import UserPreferencesCategories from "discourse/components/user-preferences/categories";
import { withPluginApi } from "discourse/lib/plugin-api";
import { MIGRATED_SELECT_KIT_MODULES } from "discourse/lib/select-kit-modify-class-deprecation";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import GroupManageCategories from "discourse/templates/group/manage/categories";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect as SelectDriver } from "discourse/tests/helpers/d-select-helper";
import {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";

const TOP = ".category-breadcrumb__category-selector";
const SUB = ".category-breadcrumb__subcategory-selector";

/** Values of the mounted options of the open panel, in order. */
function optionValues() {
  return findAll("[role='option'][data-value]").map(
    (option) => option.dataset.value
  );
}

/** Opens the breadcrumb drop matching `selector` and picks the row for `value`. */
async function pick(selector, value) {
  await click(`${selector}.d-select, ${selector} .d-select`);
  await click(`[role='option'][data-value='${value}']`);
}

module(
  "Integration | ui-kit | select | recipes | category call sites",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      this.categories = Site.current().categories;
      this.routeTo = sinon.stub(DiscourseURL, "routeTo");
      this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
    });

    module("breadcrumbs", function () {
      test("a top-level pick routes to the category", async function (assert) {
        await render(
          <template><BreadCrumbs @categories={{this.categories}} /></template>
        );
        await pick(TOP, 1);

        assert.true(this.routeToUrl.calledOnceWithExactly("/c/bug/1"));
      });

      test("a subcategory pick routes under its parent", async function (assert) {
        const category = Category.findById(2);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
            />
          </template>
        );
        await pick(SUB, 26);

        assert.true(
          this.routeToUrl.calledOnceWithExactly("/c/feature/spec/26")
        );
      });

      test("no subcategories routes to the parent's own topics", async function (assert) {
        const category = Category.findById(2);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
            />
          </template>
        );
        await pick(SUB, NO_CATEGORIES_ID);

        assert.true(this.routeToUrl.calledOnceWithExactly("/c/feature/2/none"));
      });

      test("removing a subcategory filter returns to the parent", async function (assert) {
        const category = Category.findById(26);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
            />
          </template>
        );
        await pick(SUB, ALL_CATEGORIES_ID);

        assert.true(this.routeToUrl.calledOnceWithExactly("/c/feature/2"));
      });

      test("a parent that lists no subcategories by default is asked for all of them", async function (assert) {
        const category = Category.findById(26);
        const parent = category.parentCategory;
        const previous = parent.default_list_filter;
        parent.set("default_list_filter", "none");
        try {
          await render(
            <template>
              <BreadCrumbs
                @categories={{this.categories}}
                @category={{category}}
              />
            </template>
          );
          await pick(SUB, ALL_CATEGORIES_ID);

          assert.true(
            this.routeToUrl.calledOnceWithExactly("/c/feature/2/all")
          );
        } finally {
          parent.set("default_list_filter", previous);
        }
      });

      test("leaving a no-subcategories list includes subcategories again", async function (assert) {
        const category = Category.findById(2);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
              @noSubcategories={{true}}
            />
          </template>
        );
        await pick(TOP, 1);

        assert.true(this.routeToUrl.calledOnceWithExactly("/c/bug/1"));
      });

      test("customizations reach the breadcrumbs' category drops by identifier", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forIdentifier("breadcrumb-category", (spec) =>
              spec.options(() => ({ placeholder: "breadcrumb level" }))
            );
          })
        );
        await render(
          <template><BreadCrumbs @categories={{this.categories}} /></template>
        );

        assert.dom(`${TOP} .d-select__placeholder`).hasText("breadcrumb level");
      });

      test("removing the filter at the top level routes home", async function (assert) {
        const category = Category.findById(1);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
            />
          </template>
        );
        await pick(TOP, ALL_CATEGORIES_ID);

        assert.true(this.routeToUrl.calledOnceWithExactly("/"));
      });

      test("the current tag stays in the route", async function (assert) {
        const tag = { id: 7, name: "monkey", slug: "monkey" };
        await render(
          <template>
            <BreadCrumbs @categories={{this.categories}} @tag={{tag}} />
          </template>
        );
        await pick(TOP, 1);

        assert.true(
          this.routeToUrl.calledOnceWithExactly("/tags/c/bug/1/monkey/7")
        );
      });

      test("while editing a category a pick opens the same settings tab", async function (assert) {
        const category = Category.findById(1);
        await render(
          <template>
            <BreadCrumbs
              @categories={{this.categories}}
              @category={{category}}
              @editingCategory={{true}}
              @editingCategoryTab="settings"
            />
          </template>
        );
        await pick(TOP, 3);

        assert.true(
          this.routeToUrl.calledOnceWithExactly("/c/meta/edit/settings")
        );
      });

      test("the top level lists the categories the page passes", async function (assert) {
        const categories = this.categories.filter((c) => c.id !== 3);
        await render(
          <template><BreadCrumbs @categories={{categories}} /></template>
        );
        await click(`${TOP}.d-select, ${TOP} .d-select`);

        assert.true(
          optionValues().includes("1"),
          "a passed category is listed"
        );
        assert.false(
          optionValues().includes("3"),
          "a category the page left out is not"
        );
      });
    });

    module("notification levels", function () {
      test("a preferences list offers its own held categories but not another list's", async function (assert) {
        const model = {
          watchedCategories: [Category.findById(1)],
          trackedCategories: [Category.findById(2)],
          watchedFirstPostCategories: [],
          mutedCategories: [],
        };
        const selected = [
          ...model.watchedCategories,
          ...model.trackedCategories,
        ];
        await render(
          <template>
            <UserPreferencesCategories
              @model={{model}}
              @selectedCategories={{selected}}
              @siteSettings={{this.siteSettings}}
            />
          </template>
        );
        await click(".tracking-controls__watched-categories .d-select");
        assert.true(optionValues().includes("1"), "its own category is listed");
        assert.false(
          optionValues().includes("2"),
          "the tracked category is not offered"
        );
      });

      test("picking a searched category on a lazy site fetches nothing again", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        pretender.post("/categories/search", () =>
          response({
            categories_count: 1,
            categories: [{ id: 9960, name: "Searched pick", slug: "pick9960" }],
            ancestors: [],
          })
        );
        let finds = 0;
        pretender.get("/categories/find", () => {
          finds++;
          return response({ categories: [] });
        });
        const warn = sinon.stub(console, "warn");
        const user = this.owner.lookup("service:store").createRecord("user", {
          watched_category_ids: [],
          tracked_category_ids: [],
          watched_first_post_category_ids: [],
          regular_category_ids: [],
          muted_category_ids: [],
        });
        const selected = [];

        try {
          await render(
            <template>
              <UserPreferencesCategories
                @model={{user}}
                @selectedCategories={{selected}}
                @siteSettings={{this.siteSettings}}
              />
            </template>
          );
          const picker = new SelectDriver(
            ".tracking-controls__watched-categories .d-select"
          );
          await picker.open();
          await picker.search("Searched");
          await click("[role='option'][data-value='9960']");

          assert.deepEqual(user.watched_category_ids, [9960]);
          assert.strictEqual(finds, 0, "the picked category is not fetched");
          assert.false(
            warn.calledWithMatch(/Multiple calls to Category.asyncFindByIds/),
            "no repeated lookups"
          );
        } finally {
          warn.restore();
        }
      });

      test("a group list offers its own held categories but not another list's", async function (assert) {
        const model = {
          watchingCategories: [Category.findById(1)],
          trackingCategories: [Category.findById(2)],
        };
        const controller = {
          model,
          selectedCategories: [Category.findById(1), Category.findById(2)],
          siteSettings: this.siteSettings,
        };
        await render(
          <template>
            <GroupManageCategories @controller={{controller}} />
          </template>
        );
        await click(".control-group:nth-of-type(2) .d-select");
        assert.true(optionValues().includes("1"), "its own category is listed");
        assert.false(
          optionValues().includes("2"),
          "the tracking category is not offered"
        );
      });
    });

    module("settings and search", function () {
      test("a category list setting stores ids joined by pipes", async function (assert) {
        const change = sinon.spy();
        await render(
          <template>
            <SiteSettingCategoryList
              @changeValueCallback={{change}}
              @value="1|2"
            />
          </template>
        );
        await click(".d-select__trigger");
        await click("[role='option'][data-value='3']");

        assert.true(change.calledOnceWithExactly("1|2|3"));
      });

      test("advanced search filters by the picked category", async function (assert) {
        const change = sinon.spy();
        await render(
          <template>
            <SearchAdvancedOptions
              @expandFilters={{true}}
              @onChangeSearchTerm={{change}}
              @searchTerm=""
            />
          </template>
        );
        await new SelectDriver("#search-in-category").select(26);

        assert.strictEqual(change.lastCall.args[0].trim(), "#feature:spec");
      });

      test("advanced search offers categories the user cannot post in", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9901,
            name: "Readable only",
            slug: "readable",
            permission: null,
          },
        ]);
        const change = sinon.spy();
        await render(
          <template>
            <SearchAdvancedOptions
              @expandFilters={{true}}
              @onChangeSearchTerm={{change}}
              @searchTerm=""
            />
          </template>
        );
        await new SelectDriver("#search-in-category").search("readable");

        assert.deepEqual(optionValues(), ["9901"]);
      });
    });

    module("customizations", function () {
      test("patches on the category pickers are reported once their call sites migrate", function (assert) {
        for (const path of [
          "category-chooser",
          "category-drop",
          "category-drop/category-drop-header",
          "category-drop-more-collection",
          "category-row",
          "category-selector",
          "multiple-categories-selector",
          "search-advanced-category-chooser",
          "selected-choice-category",
        ]) {
          assert.true(MIGRATED_SELECT_KIT_MODULES.has(path), path);
        }
      });
    });
  }
);
