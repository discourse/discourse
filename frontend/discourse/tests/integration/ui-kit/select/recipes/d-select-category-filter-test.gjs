import { tracked } from "@glimmer/tracking";
import { set } from "@ember/object";
import {
  click,
  find,
  findAll,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { settledAfterFrame } from "discourse/tests/helpers/qunit-helpers";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelectCategoryFilter, {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import { i18n } from "discourse-i18n";

function optionValues() {
  return findAll("[role='option'][data-value]").map(
    (option) => option.dataset.value
  );
}

/** Replaces the site's categories with 235 paged top-level ones, in activity order. */
function setPagedCategories() {
  const categories = Array.from({ length: 235 }, (_, index) =>
    Category.create({
      id: 99000 + index,
      name: `Paged category ${String(index).padStart(3, "0")}`,
      slug: `paged-${index}`,
      permission: 1,
      topic_count: 235 - index,
    })
  );
  Site.current().set("categories", categories);
  return categories;
}

function optionFor(id) {
  return find(`[role='option'][data-value='${id}']`);
}

/** The select inside `scope`, or the only one rendered. */
function select(scope = "") {
  return dSelect(`${scope} .d-select`.trim());
}

/** The query input, wherever the variant places it. */
function filterInput() {
  return find(".d-select__input, .d-select__panel .d-select__filter");
}

/** The top level as the site lists it, in its order. */
function topLevel() {
  return Site.current().categoriesList.filter(
    (category) => !category.parent_category_id
  );
}

module(
  "Integration | ui-kit | select | recipes | DSelectCategoryFilter",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.navigate = sinon.stub(DiscourseURL, "routeTo");
      this.navigateUrl = sinon.stub(DiscourseURL, "routeToUrl");
    });

    module("trigger", function () {
      test("its kind is select-category-filter and its legacy class is category-drop", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-category-filter", (spec) =>
              spec.row((row) => row.classes.push("x-category-filter"))
            );
          })
        );

        await render(<template><DSelectCategoryFilter /></template>);

        assert.dom(".d-select").hasClass("category-drop");
        await select().open();
        assert.true(
          find("[role='option']").classList.contains("x-category-filter")
        );
      });

      test("the caret points right while closed and down while open", async function (assert) {
        await render(<template><DSelectCategoryFilter /></template>);

        assert.dom(".d-select__caret").hasClass("d-icon-angle-right");
        await select().open();
        assert.dom(".d-select__caret").hasClass("d-icon-angle-down");
      });

      test("a customization can replace the caret", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-category-filter", (spec) =>
              spec.options(() => ({
                caretIcon: { open: "chevron-up", closed: "chevron-right" },
              }))
            );
          })
        );

        await render(<template><DSelectCategoryFilter /></template>);

        assert.dom(".d-select__caret").hasClass("d-icon-chevron-right");
        await select().open();
        assert.dom(".d-select__caret").hasClass("d-icon-chevron-up");
      });

      test("with no value it names the level", async function (assert) {
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="top"><DSelectCategoryFilter /></div>
            <div class="sub"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
            <div class="none"><DSelectCategoryFilter
                @noSubcategories={{true}}
                @parentCategory={{parent}}
              /></div>
          </template>
        );

        assert
          .dom(select(".top").element())
          .includesText(i18n("categories.categories_label"));
        assert
          .dom(select(".sub").element())
          .includesText(i18n("categories.subcategories_label"));
        assert
          .dom(select(".none").element())
          .includesText(i18n("categories.no_subcategories"));
      });

      test("an empty level is named for what it filters and shows the level as its placeholder", async function (assert) {
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="top"><DSelectCategoryFilter /></div>
            <div class="sub"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
            <div class="all"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{ALL_CATEGORIES_ID}}
              /></div>
          </template>
        );

        for (const [scope, label, level] of [
          [".top", "Filter by: categories", "categories"],
          [".sub", "Filter by: subcategories", "subcategories"],
          [".all", "Filter by: subcategories", "subcategories"],
        ]) {
          const root = select(scope).element();
          assert.strictEqual(root.getAttribute("aria-label"), label, scope);
          assert.strictEqual(root.dataset.value, "", `${scope} holds nothing`);
          assert
            .dom(".d-select__placeholder", root)
            .hasText(level, `${scope} shows the level`);
        }
      });

      test("a held filter follows the level's name", async function (assert) {
        const parent = Category.findById(2);
        const value = Category.findById(26);

        await render(
          <template>
            <div class="held"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{value}}
              /></div>
            <div class="none"><DSelectCategoryFilter
                @noSubcategories={{true}}
                @parentCategory={{parent}}
              /></div>
          </template>
        );

        assert.strictEqual(
          select(".held").element().getAttribute("aria-label"),
          "Filter by: subcategories, spec"
        );
        assert.strictEqual(
          select(".none").element().getAttribute("aria-label"),
          "Filter by: subcategories, no subcategories"
        );
        assert.strictEqual(
          select(".none").element().dataset.value,
          NO_CATEGORIES_ID,
          "no subcategories is a held filter"
        );
      });

      test("a call site or a customization can replace the empty level's text", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-category-filter", (spec) =>
              spec.options((previous, { kindContext }) =>
                kindContext.parentCategory?.id === 2
                  ? { placeholder: "pick a child" }
                  : undefined
              )
            );
          })
        );
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="top"><DSelectCategoryFilter
                @placeholder="any category"
              /></div>
            <div class="sub"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
          </template>
        );

        assert
          .dom(".d-select__placeholder", select(".top").element())
          .hasText("any category", "the call site's text");
        assert
          .dom(".d-select__placeholder", select(".sub").element())
          .hasText("pick a child", "one parent's drop, customized");
      });

      test("adjacent levels have distinct accessible names", async function (assert) {
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="top"><DSelectCategoryFilter /></div>
            <div class="sub"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
          </template>
        );

        const name = (scope) => {
          const control =
            select(scope)
              .element()
              .querySelector("[aria-label], [aria-labelledby]") ??
            select(scope).element();
          const labelledBy = control.getAttribute("aria-labelledby");
          return labelledBy
            ? labelledBy
                .split(" ")
                .map((id) => document.getElementById(id)?.textContent.trim())
                .join(" ")
            : control.getAttribute("aria-label");
        };

        assert.notStrictEqual(name(".top"), name(".sub"));
      });

      test("marks the trigger while a category narrows the list", async function (assert) {
        const parent = Category.findById(2);
        const value = Category.findById(26);

        await render(
          <template>
            <div class="all"><DSelectCategoryFilter /></div>
            <div class="held"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{value}}
              /></div>
            <div class="none"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{NO_CATEGORIES_ID}}
              /></div>
          </template>
        );

        assert.dom(select(".all").element()).doesNotHaveClass("--filtering");
        assert.dom(select(".held").element()).hasClass("--filtering");
        assert.dom(select(".none").element()).hasClass("--filtering");
      });

      test("the held category shows its own badge", async function (assert) {
        const parent = Category.findById(2);
        const value = Category.findById(26);

        await render(
          <template>
            <DSelectCategoryFilter
              @parentCategory={{parent}}
              @value={{value}}
            />
          </template>
        );

        assert.deepEqual(
          [...select().element().querySelectorAll(".badge-category__name")].map(
            (el) => el.textContent.trim()
          ),
          ["spec"],
          "no parent badge"
        );
      });
    });

    module("browsing", function () {
      test("lists the top level in the site's order, without shortcuts when nothing is held", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = true;
        const items = topLevel();

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();

        assert.deepEqual(
          optionValues(),
          items
            .map((category) => String(category.id))
            .slice(0, optionValues().length)
        );
      });

      test("uncategorized follows the site setting", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = false;

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();

        assert.dom(optionFor(17)).doesNotExist();
      });

      test("a held top-level category offers to remove the filter", async function (assert) {
        const items = topLevel();
        const value = items[0];

        await render(
          <template><DSelectCategoryFilter @value={{value}} /></template>
        );
        await select().open();

        assert.strictEqual(optionValues()[0], ALL_CATEGORIES_ID);
        assert
          .dom(optionFor(ALL_CATEGORIES_ID))
          .includesText(i18n("categories.remove_filter"));
      });

      test("a subcategory level offers no subcategories, and both shortcuts once one is held", async function (assert) {
        const parent = Category.findById(2);
        const held = Category.findById(26);

        await render(
          <template>
            <div class="empty"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
            <div class="held"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{held}}
              /></div>
          </template>
        );

        await select(".empty").open();
        assert.strictEqual(optionValues()[0], NO_CATEGORIES_ID);
        assert
          .dom(optionFor(NO_CATEGORIES_ID))
          .includesText(i18n("categories.no_subcategories"));
        await select(".empty").close();

        await select(".held").open();
        assert.deepEqual(optionValues().slice(0, 2), [
          ALL_CATEGORIES_ID,
          NO_CATEGORIES_ID,
        ]);
      });

      test("a held no-subcategories filter offers only to remove the filter", async function (assert) {
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="flag"><DSelectCategoryFilter
                @noSubcategories={{true}}
                @parentCategory={{parent}}
              /></div>
            <div class="value"><DSelectCategoryFilter
                @parentCategory={{parent}}
                @value={{NO_CATEGORIES_ID}}
              /></div>
          </template>
        );

        for (const scope of [".flag", ".value"]) {
          await select(scope).open();
          assert.strictEqual(optionValues()[0], ALL_CATEGORIES_ID, scope);
          assert
            .dom(optionFor(ALL_CATEGORIES_ID))
            .includesText(i18n("categories.remove_filter"));
          assert
            .dom(optionFor(NO_CATEGORIES_ID))
            .doesNotExist(`${scope} does not offer the held filter again`);
          await select(scope).close();
        }
      });

      test("toggling editing updates the shortcuts without reloading the level", async function (assert) {
        const items = topLevel();
        const value = items[0];
        const editing = tracked(false);
        let loads = 0;
        const load = () => {
          loads++;
          return items.map((category) => ({
            id: category.id,
            name: category.name,
          }));
        };

        await render(
          <template>
            <DSelectCategoryFilter
              @editing={{editing.value}}
              @load={{load}}
              @value={{value}}
            />
          </template>
        );
        await select().open();
        assert.dom(optionFor(ALL_CATEGORIES_ID)).exists();

        editing.value = true;
        await settled();

        assert.dom(optionFor(ALL_CATEGORIES_ID)).doesNotExist();
        assert.strictEqual(loads, 1, "the level is not asked again");
      });

      test("editing offers no shortcut back to every category", async function (assert) {
        const items = topLevel();
        const value = items[0];

        await render(
          <template>
            <DSelectCategoryFilter @editing={{true}} @value={{value}} />
          </template>
        );
        await select().open();

        assert.dom(optionFor(ALL_CATEGORIES_ID)).doesNotExist();
      });

      test("subcategory rows hide their parent", async function (assert) {
        const parent = Category.findById(2);

        await render(
          <template>
            <DSelectCategoryFilter @parentCategory={{parent}} />
          </template>
        );
        await select().open();

        assert.deepEqual(
          [...optionFor(26).querySelectorAll(".badge-category__name")].map(
            (el) => el.textContent.trim()
          ),
          ["spec"]
        );
      });

      test("topic counts can include subcategories", async function (assert) {
        await render(
          <template>
            <div class="own"><DSelectCategoryFilter /></div>
            <div class="all"><DSelectCategoryFilter
                @countSubcategories={{true}}
              /></div>
          </template>
        );

        await select(".own").open();
        assert.true(optionFor(7).textContent.includes("481"));
        await select(".own").close();

        await select(".all").open();
        assert.true(optionFor(7).textContent.includes("584"));
      });

      test("descriptions show only to newcomers", async function (assert) {
        const items = topLevel();
        const id = items[0].id;

        set(this.currentUser, "staff", false);
        set(this.currentUser, "moderator", false);
        set(this.currentUser, "admin", false);
        set(this.currentUser, "trust_level", 0);
        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        assert
          .dom(".d-select__option-description", optionFor(id))
          .exists("a TL0 user sees them");
        await select().close();

        set(this.currentUser, "trust_level", 1);
        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        assert
          .dom(".d-select__option-description", optionFor(id))
          .doesNotExist("TL1 does not");
        await select().close();

        set(this.currentUser, "trust_level", 0);
        set(this.currentUser, "moderator", true);
        set(this.currentUser, "staff", true);
        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        assert
          .dom(".d-select__option-description", optionFor(id))
          .doesNotExist("staff do not");
      });
    });

    module("muted categories", function () {
      test("a level leaves out categories muted through their parent", async function (assert) {
        this.owner
          .lookup("service:current-user")
          .set("indirectly_muted_category_ids", [28]);
        const parent = Category.findById(7);

        await render(
          <template>
            <DSelectCategoryFilter @parentCategory={{parent}} />
          </template>
        );
        await select().open();

        assert.dom(optionFor(28)).doesNotExist("muted through its parent");
        assert.dom(optionFor(27)).exists("its sibling stays");
      });

      test("a category muted directly stays listed", async function (assert) {
        const currentUser = this.owner.lookup("service:current-user");
        currentUser.set("muted_category_ids", [28]);
        currentUser.set("indirectly_muted_category_ids", []);
        const parent = Category.findById(7);

        await render(
          <template>
            <DSelectCategoryFilter @parentCategory={{parent}} />
          </template>
        );
        await select().open();

        assert.dom(optionFor(28)).exists();
      });

      test("a search leaves out categories muted through their parent", async function (assert) {
        this.owner
          .lookup("service:current-user")
          .set("indirectly_muted_category_ids", [28]);

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await select().search("hack");
        assert.deepEqual(optionValues(), [], "the muted match is left out");

        await select().search("translations");
        assert.deepEqual(optionValues(), ["27"], "other matches stay");
      });
    });

    module("choosing", function () {
      test("emits the Category or the shortcut and never navigates", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9700,
            name: "Spectrum",
            slug: "spectrum",
            parent_category_id: 2,
            permission: 1,
          },
        ]);
        const onChange = sinon.spy();
        const parent = Category.findById(2);
        const held = Category.findById(26);

        await render(
          <template>
            <DSelectCategoryFilter
              @onChange={{onChange}}
              @parentCategory={{parent}}
              @value={{held}}
            />
          </template>
        );

        await select().open();
        await click(optionFor(NO_CATEGORIES_ID));
        assert.strictEqual(onChange.lastCall.args[0], NO_CATEGORIES_ID);

        await select().open();
        await click(optionFor(ALL_CATEGORIES_ID));
        assert.strictEqual(onChange.lastCall.args[0], ALL_CATEGORIES_ID);

        await select().open();
        await select().search("spectrum");
        await click(optionFor(9700));
        assert.strictEqual(
          onChange.lastCall.args[0],
          Category.findById(9700),
          "a pick that changes the value emits the record"
        );

        assert.false(this.navigate.called, "no routeTo");
        assert.false(this.navigateUrl.called, "no routeToUrl");
      });
    });

    module("searching", function () {
      test("at the top level a search spans the site, prefix matches first and top-level categories before children", async function (assert) {
        Site.current().updateCategories([
          { id: 9801, name: "Alpha docs", slug: "alpha-docs", permission: 1 },
          {
            id: 9802,
            name: "Docs",
            slug: "docs",
            parent_category_id: 9801,
            permission: 1,
          },
          { id: 9803, name: "Docs hub", slug: "docs-hub", permission: 1 },
        ]);
        const items = topLevel();
        const value = items[0];

        await render(
          <template><DSelectCategoryFilter @value={{value}} /></template>
        );
        await select().open();
        await select().search("docs");

        assert.deepEqual(
          optionValues(),
          ["9803", "9802", "9801"],
          "prefix before substring, then top level before children, and no shortcuts"
        );
      });

      test("a preloaded site matches every word of the name, not the slug", async function (assert) {
        Site.current().updateCategories([
          { id: 9821, name: "Questions", slug: "qa", permission: 1 },
          { id: 9822, name: "Docs alpha", slug: "docs-alpha", permission: 1 },
        ]);
        const requests = [];
        pretender.post("/categories/search", (request) => {
          requests.push(request);
          return response({ categories: [], ancestors: [] });
        });

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await select().search("qa");
        assert.deepEqual(optionValues(), [], "a slug alone does not match");

        await select().search("alpha docs");
        assert.deepEqual(optionValues(), ["9822"], "words match in any order");
        assert.strictEqual(requests.length, 0, "answered without a request");
      });

      test("a search is not limited to five results", async function (assert) {
        Site.current().updateCategories(
          Array.from({ length: 8 }, (_, index) => ({
            id: 9810 + index,
            name: `Zebra ${index}`,
            slug: `zebra-${index}`,
            permission: 1,
          }))
        );

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await select().search("zebra");

        assert.strictEqual(optionValues().length, 8);
      });

      test("below the top level a search keeps to the parent's direct children", async function (assert) {
        const parent = Category.findById(7);

        await render(
          <template>
            <DSelectCategoryFilter @parentCategory={{parent}} />
          </template>
        );
        await select().open();
        await select().search("a");

        assert.deepEqual(optionValues().sort(), ["27", "28"]);
        assert.dom(optionFor(NO_CATEGORIES_ID)).doesNotExist("no shortcuts");
      });

      test("a keyboard pick on a typed match commits without waiting", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template><DSelectCategoryFilter @onChange={{onChange}} /></template>
        );
        await select().open();
        await select().search("bug");
        await triggerKeyEvent(filterInput(), "keydown", "ArrowDown");
        await triggerKeyEvent(filterInput(), "keydown", "Enter");

        assert.strictEqual(onChange.lastCall?.args[0], Category.findById(1));
      });
    });

    module("lazy loading", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        Site.current().set("lazy_load_categories", true);
      });

      /** Returns `count` top-level rows from the server and records each request. */
      function stubLevel(count) {
        const requests = [];
        pretender.post("/categories/search", (request) => {
          const params = new URLSearchParams(request.requestBody);
          requests.push(params);
          const rows = Array.from({ length: count }, (_, index) => ({
            id: 9900 + index,
            name: `Remote ${index}`,
            slug: `remote-${index}`,
            permission: 1,
          }));
          const limit = Number(params.get("limit") || 25);
          const page = Number(params.get("page") || 1);
          return response({
            categories_count: count,
            categories: rows.slice((page - 1) * limit, page * limit),
            ancestors: [],
          });
        });
        return requests;
      }

      test("browsing asks the server for the level", async function (assert) {
        const requests = stubLevel(3);
        const parent = Category.findById(2);

        await render(
          <template>
            <div class="top"><DSelectCategoryFilter /></div>
            <div class="sub"><DSelectCategoryFilter
                @parentCategory={{parent}}
              /></div>
          </template>
        );

        await select(".top").open();
        await settled();
        assert.strictEqual(requests.at(-1).get("parent_category_id"), "-1");
        assert.deepEqual(optionValues(), ["9900", "9901", "9902"]);
        await select(".top").close();

        await select(".sub").open();
        await settled();
        assert.strictEqual(requests.at(-1).get("parent_category_id"), "2");
      });

      test("browsing and searching ask the server to leave out indirectly muted categories", async function (assert) {
        const requests = stubLevel(3);

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await settled();
        assert.strictEqual(
          requests.at(-1).get("reject_indirectly_muted"),
          "true",
          "browsing"
        );

        await select().search("remote");
        await settled();
        assert.strictEqual(
          requests.at(-1).get("reject_indirectly_muted"),
          "true",
          "searching"
        );
      });

      test("changing the mutes reloads an open level, and an equal list does not", async function (assert) {
        const currentUser = this.owner.lookup("service:current-user");
        currentUser.set("indirectly_muted_category_ids", [28]);
        const requests = stubLevel(3);

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await settled();
        const opened = requests.length;

        currentUser.set("indirectly_muted_category_ids", [28]);
        await settled();
        assert.strictEqual(requests.length, opened, "the same mutes");

        currentUser.set("indirectly_muted_category_ids", [28, 27]);
        await settled();
        assert.strictEqual(requests.length, opened + 1, "a new mute");
      });

      test("browsing lists the level in the preloaded order", async function (assert) {
        const requests = stubLevel(3);

        await render(<template><DSelectCategoryFilter /></template>);
        await select().open();
        await settled();
        assert.strictEqual(
          requests.at(-1).get("tree_order"),
          "topics",
          "by topic count, as the site's list"
        );
        await select().close();

        this.siteSettings.fixed_category_positions = true;
        await select().open();
        await settled();
        assert.strictEqual(
          requests.at(-1).get("tree_order"),
          "position",
          "by position when positions are fixed"
        );
      });

      test("a long level reaches every category by scrolling", async function (assert) {
        enableVirtualization();
        try {
          const requests = stubLevel(30);

          await render(<template><DSelectCategoryFilter /></template>);
          await select().open();
          await settled();
          for (let scroll = 0; scroll < 3; scroll++) {
            const list = find(".d-virtual-list");
            list.scrollTop = list.scrollHeight;
            await triggerEvent(list, "scroll");
            await settledAfterFrame();
          }

          assert.strictEqual(requests.at(-1).get("page"), "2");
          assert
            .dom("[role='option'][data-value='9929']")
            .hasAttribute("aria-setsize", "30");
          assert.dom(".d-select__footer").doesNotExist("no count or link");
        } finally {
          disableVirtualization();
        }
      });
    });

    module("edge cases", function () {
      test("filter badges omit ancestors on held and listed children", async function (assert) {
        const parent = Category.findById(2);
        const value = Category.findById(26);
        await render(
          <template>
            <DSelectCategoryFilter
              @parentCategory={{parent}}
              @value={{value}}
            />
          </template>
        );
        assert.deepEqual(
          findAll(".d-select .badge-category__name").map((node) =>
            node.textContent.trim()
          ),
          ["spec"],
          "own badge on trigger"
        );
        await dSelect().open();
        assert.deepEqual(
          findAll("[role='option'][data-value='26'] .badge-category__name").map(
            (node) => node.textContent.trim()
          ),
          ["spec"],
          "own badge on row"
        );
      });

      test("filter search ranks restricted and public categories alike, by prefix, level, then id", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9801,
            name: "Orchid prefix",
            slug: "orchid-prefix",
            read_restricted: true,
            permission: 1,
          },
          { id: 9802, name: "An orchid", slug: "an-orchid", permission: 1 },
          {
            id: 9803,
            name: "Orchid public",
            slug: "orchid-public",
            permission: 1,
          },
          {
            id: 9804,
            name: "Orchid child",
            slug: "orchid-child",
            parent_category_id: 2,
            permission: 1,
          },
        ]);
        await render(<template><DSelectCategoryFilter /></template>);
        await dSelect().open();
        await dSelect().search("orchid");
        assert.deepEqual(
          optionValues(),
          ["9801", "9803", "9804", "9802"],
          "prefix, then level, then id; access does not rank"
        );
      });

      test("filter source replacement preserves rows and paging", async function (assert) {
        enableVirtualization();
        try {
          const rows = Site.current().categories.map((category) => ({
            id: category.id,
            name: category.name,
          }));
          const cursors = [];
          const load = (_query, { cursor }) => {
            cursors.push(cursor);
            return {
              items: cursor ? rows.slice(20) : rows.slice(0, 20),
              total: rows.length,
              hasMore: !cursor,
              cursor: "tail",
            };
          };
          await render(
            <template>
              <DSelectCategoryFilter @load={{load}} @uncategorized={{true}} />
            </template>
          );
          await dSelect().open();
          const list = find(".d-virtual-list");
          list.scrollTop = list.scrollHeight;
          await triggerEvent(list, "scroll");
          await settledAfterFrame();
          assert.deepEqual(
            cursors,
            [undefined, "tail"],
            "the source's cursor reaches its next request"
          );
          // Measured rows can outgrow the estimate, so read on to the new end as a reader would.
          list.scrollTop = list.scrollHeight;
          await triggerEvent(list, "scroll");
          await settledAfterFrame();
          assert
            .dom(`[role='option'][data-value='${rows.at(-1).id}']`)
            .exists("the final source row is reachable");
        } finally {
          disableVirtualization();
        }
      });

      test("anonymous filter users see decoded descriptions", async function (assert) {
        this.owner.unregister("service:current-user");
        this.owner.register("service:current-user", null, {
          instantiate: false,
        });
        await render(<template><DSelectCategoryFilter /></template>);
        await dSelect().open();
        assert
          .dom("[role='option'] .d-select__option-description")
          .exists("anonymous descriptions are visible");
      });

      test("a picked row the site does not know is listed but emits nothing and warns", async function (assert) {
        const load = () => [{ id: 99001, name: "Caller category" }];
        const onChange = sinon.spy();
        const warn = sinon.stub(console, "warn");
        await render(
          <template>
            <DSelectCategoryFilter @load={{load}} @onChange={{onChange}} />
          </template>
        );
        await dSelect().open();
        assert
          .dom("[role='option'][data-value='99001']")
          .includesText("Caller category", "the caller's row is listed");

        await click("[role='option'][data-value='99001']");

        assert.true(onChange.notCalled, "only a site category can be routed");
        assert.strictEqual(
          warn
            .getCalls()
            .filter(({ args }) =>
              String(args[0]).includes("DSelectCategoryFilter")
            ).length,
          1,
          "the dropped pick is reported once"
        );
        warn.restore();
      });

      test("mounts a window of the local list and reports the full matching count", async function (assert) {
        enableVirtualization();
        try {
          const categories = setPagedCategories();
          await render(<template><DSelectCategoryFilter /></template>);
          await dSelect().open();
          assert.true(
            optionValues().length < categories.length,
            "browsing mounts a window, not the whole list"
          );
          assert.dom("[role='option']").hasAttribute("aria-setsize", "235");
          await dSelect().search("Paged category");
          assert.true(
            optionValues().length < categories.length,
            "search mounts a window, not the whole list"
          );
          assert.dom("[role='option']").hasAttribute("aria-setsize", "235");
          assert.deepEqual(
            optionValues(),
            categories
              .slice(0, optionValues().length)
              .map((category) => String(category.id)),
            "the window starts in activity order"
          );
        } finally {
          disableVirtualization();
        }
      });

      test("reveals every local search page in order", async function (assert) {
        enableVirtualization();
        try {
          const categories = setPagedCategories();
          const onChange = sinon.spy();
          await render(
            <template>
              <DSelectCategoryFilter @onChange={{onChange}} />
            </template>
          );
          await dSelect().open();
          await dSelect().search("Paged category");
          for (let scroll = 0; scroll < 10; scroll++) {
            const list = find(".d-virtual-list");
            list.scrollTop = list.scrollHeight;
            await triggerEvent(list, "scroll");
            await settledAfterFrame();
          }
          assert
            .dom("[data-value='99234'][role='option']")
            .hasAttribute("aria-posinset", "235")
            .hasAttribute("aria-setsize", "235");
          await click("[data-value='99234'][role='option']");
          const emitted = onChange.lastCall.args[0];
          assert.strictEqual(
            Array.isArray(emitted) ? emitted[0] : emitted,
            categories[234],
            "the final page emits its site record"
          );
        } finally {
          disableVirtualization();
        }
      });

      test("follows source continuation with twenty-row server pages", async function (assert) {
        enableVirtualization();
        try {
          Site.current().set("lazy_load_categories", true);
          const pages = [];
          pretender.post("/categories/search", (request) => {
            const page = Number(
              new URLSearchParams(request.requestBody).get("page") || 1
            );
            pages.push(page);
            return response({
              categories_count: 45,
              categories: Array.from(
                { length: Math.min(20, 45 - (page - 1) * 20) },
                (_, index) => ({
                  id: 99000 + (page - 1) * 20 + index,
                  name: `Remote ${index}`,
                  slug: `remote-${index}`,
                  permission: 1,
                  has_children: false,
                })
              ),
              ancestors: [],
            });
          });
          await render(<template><DSelectCategoryFilter /></template>);
          await dSelect().open();
          await dSelect().search("Remote");
          for (let scroll = 0; scroll < 2; scroll++) {
            const list = find(".d-virtual-list");
            list.scrollTop = list.scrollHeight;
            await triggerEvent(list, "scroll");
            await settledAfterFrame();
          }
          assert.true(pages.includes(3), "the third server page is requested");
          assert.strictEqual(
            Number(find("[role='option']").getAttribute("aria-setsize")),
            45,
            "all forty-five matches remain reachable"
          );
        } finally {
          disableVirtualization();
        }
      });
    });
  }
);
