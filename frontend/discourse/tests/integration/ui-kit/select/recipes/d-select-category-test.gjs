import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  click,
  find,
  findAll,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
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
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import I18n, { i18n } from "discourse-i18n";

/** Values of the mounted options of the open panel, in order. */
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

/** The option for a category id. */
function optionFor(id) {
  return find(`[role='option'][data-value='${id}']`);
}

/** The full set size the listbox declares, independent of windowing. */
function setSize() {
  return Number(find("[role='option']")?.getAttribute("aria-setsize") ?? 0);
}

/** The select inside `scope`, or the only one rendered. */
function select(scope = "") {
  return dSelect(`${scope} .d-select`.trim());
}

/** The query input, wherever the variant places it. */
function filterInput() {
  return find(".d-select__input, .d-select__panel .d-select__filter");
}

/** The text a closed trigger offers with no value, whichever variant renders it. */
function placeholderText(scope = "") {
  const root = select(scope).element();
  const label = root.querySelector(".d-select__placeholder");
  if (label) {
    return label.textContent.trim();
  }
  return (
    root.querySelector("[role='combobox']")?.getAttribute("placeholder") ?? ""
  );
}

/** The held selection a closed single trigger shows, whichever variant renders it. */
function shownValue(scope = "") {
  const root = select(scope).element();
  const presented = root.querySelector(
    ".d-select__value, .d-select__presentation"
  );
  return (
    presented?.textContent.trim() ||
    root.querySelector("[role='combobox']")?.value
  );
}

/** Server rows for the categories the client already knows, as the search endpoint returns them. */
function serverRow(category) {
  return {
    id: category.id,
    name: category.name,
    slug: category.slug,
    color: category.color,
    text_color: category.text_color,
    parent_category_id: category.parent_category_id,
    permission: category.permission,
    topic_count: category.topic_count,
    description_text: category.description_text,
    has_children: Site.current().categories.some(
      (other) => other.parent_category_id === category.id
    ),
  };
}

/**
 * Emulates `POST /categories/search` over a fixed table: visibility only, each word
 * of the term against the name, server order, 25 rows a page.
 */
function stubServer(table) {
  const requests = [];
  pretender.post("/categories/search", (request) => {
    const params = new URLSearchParams(request.requestBody);
    requests.push(params);
    const term = (params.get("term") ?? "").toLowerCase();
    const parent = params.get("parent_category_id");
    const reject = params.getAll("reject_category_ids[]").map(Number);
    let rows = table.filter((row) =>
      term
        .split(/\s+/)
        .filter(Boolean)
        .every((word) => row.name.toLowerCase().includes(word))
    );
    if (parent === "-1") {
      rows = rows.filter((row) => !row.parent_category_id);
    } else if (parent) {
      rows = rows.filter((row) => row.parent_category_id === Number(parent));
    }
    if (params.get("include_uncategorized") === "false") {
      rows = rows.filter(
        (row) => row.id !== Site.current().uncategorized_category_id
      );
    }
    if (params.get("include_subcategories") === "false") {
      rows = rows.filter((row) => !row.parent_category_id);
    }
    if (params.get("only_postable") === "true") {
      rows = rows.filter((row) => row.permission === 1);
    }
    rows = rows.filter((row) => !reject.includes(row.id));
    const page = Number(params.get("page") || 1);
    return response({
      categories_count: rows.length,
      categories: rows.slice((page - 1) * 25, page * 25),
      ancestors: [],
    });
  });
  return requests;
}

/** A controlled `DSelectCategory`, as a call site would own it. */
class Host extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value) {
    this.args.onChange?.(value);
    this.value = value;
  }

  <template>
    <DSelectCategory
      @descriptions={{@descriptions}}
      @emit={{@emit}}
      @exclude={{@exclude}}
      @legacyKind={{@legacyKind}}
      @multiple={{@multiple}}
      @noneLabel={{@noneLabel}}
      @onChange={{this.onChange}}
      @permission={{@permission}}
      @placeholder={{@placeholder}}
      @prioritize={{@prioritize}}
      @readOnly={{@readOnly}}
      @scope={{@scope}}
      @selectDescendants={{@selectDescendants}}
      @showAncestors={{@showAncestors}}
      @subcategories={{@subcategories}}
      @uncategorized={{@uncategorized}}
      @value={{this.value}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | recipes | DSelectCategory",
  function (hooks) {
    setupRenderingTest(hooks);

    module("kind and values", function () {
      test("its kind is select-category and its legacy class follows the mode", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-category", (spec) =>
              spec.row((row) => row.classes.push("x-select-category"))
            );
          })
        );

        await render(
          <template>
            <div class="single"><Host @multiple={{false}} /></div>
            <div class="multiple"><Host /></div>
            <div class="legacy"><Host
                @legacyKind="multiple-categories-selector"
              /></div>
          </template>
        );

        assert.dom(".single .d-select").hasClass("category-chooser");
        assert.dom(".multiple .d-select").hasClass("category-selector");
        assert
          .dom(".legacy .d-select")
          .hasClass("multiple-categories-selector");

        await select(".single").open();
        assert.true(
          find("[role='option']").classList.contains("x-select-category"),
          "rows go through the select-category kind"
        );
      });

      test("single mode shows the held category and emits the picked Category", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template>
            <Host @multiple={{false}} @onChange={{onChange}} @value={{2}} />
          </template>
        );

        assert.true(
          shownValue().includes("feature"),
          "a held id renders its category"
        );

        await select().open();
        await click(optionFor(1));

        assert.strictEqual(
          onChange.lastCall.args[0],
          Category.findById(1),
          "the site's Category record"
        );
      });

      test("held values may be ids, numeric strings or Category objects", async function (assert) {
        const held = [1, "2", Category.findById(3)];

        await render(<template><Host @value={{held}} /></template>);

        assert.deepEqual(
          findAll(".d-select__chip").map((chip) => chip.dataset.value),
          ["1", "2", "3"]
        );
      });

      test("multiple mode emits Category objects, dropping ids that cannot be found", async function (assert) {
        const onChange = sinon.spy();
        const held = [1, 999999];

        await render(
          <template><Host @onChange={{onChange}} @value={{held}} /></template>
        );
        await select().open();
        await click(optionFor(2));

        assert.deepEqual(onChange.lastCall.args[0], [
          Category.findById(1),
          Category.findById(2),
        ]);
      });

      test("@emit=ids emits ids and keeps ones that cannot be found", async function (assert) {
        const multipleChange = sinon.spy();
        const singleChange = sinon.spy();
        const held = [999999];

        await render(
          <template>
            <div class="multiple"><Host
                @emit="ids"
                @onChange={{multipleChange}}
                @value={{held}}
              /></div>
            <div class="single"><Host
                @emit="ids"
                @multiple={{false}}
                @onChange={{singleChange}}
              /></div>
          </template>
        );

        await select(".multiple").open();
        await click(optionFor(2));
        assert.deepEqual(multipleChange.lastCall.args[0], [999999, 2]);
        await select(".multiple").close();

        await select(".single").open();
        await click(optionFor(2));
        assert.strictEqual(singleChange.lastCall.args[0], 2);
      });
    });

    module("browsing", function () {
      test("lists every visible category in activity order", async function (assert) {
        const expected = Site.current().sortedCategories.map((category) =>
          String(category.id)
        );

        await render(<template><Host /></template>);
        await select().open();

        assert.strictEqual(setSize(), expected.length, "every category");
        assert.deepEqual(
          optionValues(),
          expected.slice(0, optionValues().length),
          "in activity order"
        );
      });

      test("create permission keeps only categories the user can post in", async function (assert) {
        Site.current().updateCategories([
          { id: 9500, name: "Reply only", slug: "reply-only", permission: 2 },
          { id: 9501, name: "Read only", slug: "read-only", permission: null },
        ]);

        await render(
          <template>
            <div class="create"><Host @permission="create" /></div>
            <div class="see"><Host /></div>
          </template>
        );

        await select(".create").open();
        await select(".create").search("only");
        assert.deepEqual(optionValues(), [], "neither is postable");
        await select(".create").close();

        await select(".see").open();
        await select(".see").search("only");
        assert.deepEqual(
          optionValues().sort(),
          ["9500", "9501"],
          "seeing is enough by default"
        );
      });

      test("uncategorized follows the site setting when single and is listed when multiple", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = false;

        await render(
          <template>
            <div class="single"><Host @multiple={{false}} /></div>
            <div class="multiple"><Host /></div>
            <div class="forced"><Host
                @multiple={{false}}
                @uncategorized={{true}}
              /></div>
          </template>
        );

        await select(".single").open();
        await select(".single").search("uncategorized");
        assert.deepEqual(optionValues(), [], "the setting hides it");
        await select(".single").close();

        await select(".multiple").open();
        await select(".multiple").search("uncategorized");
        assert.deepEqual(optionValues(), ["17"], "multiple lists it");
        await select(".multiple").close();

        await select(".forced").open();
        await select(".forced").search("uncategorized");
        assert.deepEqual(optionValues(), ["17"], "the argument wins");
      });

      test("subcategories can be left out", async function (assert) {
        await render(
          <template>
            <Host @multiple={{false}} @subcategories={{false}} />
          </template>
        );
        await select().open();
        await select().search("category");

        assert.deepEqual(optionValues(), ["1001"]);
      });

      test("excluded categories are hidden unless held", async function (assert) {
        const exclude = [1, 2];
        const held = [2];

        await render(
          <template><Host @exclude={{exclude}} @value={{held}} /></template>
        );
        await select().open();
        await select().search("bug");
        assert.deepEqual(optionValues(), [], "excluded");

        await select().search("feature");
        assert.true(
          optionValues().includes("2"),
          "a held category stays listed"
        );
      });

      test("a scope lists the category one level up and its children, until a search", async function (assert) {
        await render(
          <template>
            <div class="root"><Host @multiple={{false}} @scope={{2}} /></div>
            <div class="child"><Host @multiple={{false}} @scope={{26}} /></div>
            <div class="grandchild"><Host
                @multiple={{false}}
                @scope={{1003}}
              /></div>
          </template>
        );

        await select(".root").open();
        assert.deepEqual(
          optionValues(),
          ["2", "26"],
          "the scope and its child"
        );
        await select(".root").search("bug");
        assert.deepEqual(
          optionValues(),
          ["1"],
          "search finds outside the scope"
        );
        await select(".root").close();

        await select(".child").open();
        assert.deepEqual(
          optionValues(),
          ["2", "26"],
          "a subcategory scopes to its parent's family"
        );
        await select(".child").close();

        await select(".grandchild").open();
        assert.deepEqual(
          optionValues(),
          ["1002", "1003"],
          "a grandchild scopes to its parent, not the root"
        );
      });

      test("prioritize lists that family first, then everything else", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = true;
        const total = Site.current().sortedCategories.length;

        await render(
          <template><Host @multiple={{false}} @prioritize={{5}} /></template>
        );
        await select().open();

        assert.deepEqual(optionValues().slice(0, 5), [
          "5",
          "22",
          "6",
          "21",
          "1",
        ]);
        assert.strictEqual(setSize(), total, "nothing is hidden");

        await select().search("bug");
        assert.deepEqual(
          optionValues(),
          ["1"],
          "search still finds categories"
        );
      });

      test("the read-only category is listed, disabled and described, despite scope and permission", async function (assert) {
        Site.current().updateCategories([
          { id: 9600, name: "Announcements", slug: "news", permission: null },
        ]);
        const onChange = sinon.spy();

        await render(
          <template>
            <Host
              @multiple={{false}}
              @onChange={{onChange}}
              @permission="create"
              @readOnly={{9600}}
              @scope={{2}}
            />
          </template>
        );
        await select().open();

        assert.deepEqual(optionValues().sort(), ["2", "26", "9600"]);
        assert.dom(optionFor(9600)).hasAttribute("aria-disabled", "true");
        assert
          .dom(".d-select__option-description", optionFor(9600))
          .hasText(i18n("category_row.read_only_description"));

        await click(optionFor(9600));
        assert.false(onChange.called, "it cannot be picked");

        await select().search("bug");
        assert.deepEqual(
          optionValues(),
          ["1"],
          "a search lists it only when it matches"
        );
        await select().search("announce");
        assert.deepEqual(optionValues(), ["9600"]);
      });

      test("@noneLabel adds a selectable row that clears the value", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template>
            <Host
              @multiple={{false}}
              @noneLabel="Any category"
              @onChange={{onChange}}
              @value={{2}}
            />
          </template>
        );
        await select().open();
        await click("[role='option'].--none");

        assert.strictEqual(onChange.lastCall.args[0], null);
      });
    });

    module("searching", function () {
      test("single mode matches the name or the parent name, ignoring case", async function (assert) {
        await render(<template><Host @multiple={{false}} /></template>);
        await select().open();

        await select().search("Bug");
        assert.deepEqual(optionValues(), ["1"]);

        await select().search("feature");
        assert.deepEqual(
          optionValues().sort(),
          ["2", "26"],
          "a child matches through its parent"
        );
      });

      test("multiple mode matches the name only", async function (assert) {
        await render(
          <template><Host @selectDescendants={{false}} /></template>
        );
        await select().open();
        await select().search("feature");

        assert.deepEqual(optionValues(), ["2"]);
      });

      test("search ignores accents", async function (assert) {
        Site.current().updateCategories([
          { id: 9700, name: "Café", slug: "cafe", permission: 1 },
          { id: 9701, name: "chữ Quốc ngữ", slug: "chu", permission: 1 },
        ]);

        await render(<template><Host @multiple={{false}} /></template>);
        await select().open();

        await select().search("cafe");
        assert.deepEqual(optionValues(), ["9700"]);
        await select().search("gữ");
        assert.deepEqual(optionValues(), ["9701"]);
      });

      test("a keyboard pick on a typed match commits without waiting", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template>
            <Host @emit="ids" @multiple={{false}} @onChange={{onChange}} />
          </template>
        );
        await select().open();
        await select().search("bug");
        await triggerKeyEvent(filterInput(), "keydown", "ArrowDown");
        await triggerKeyEvent(filterInput(), "keydown", "Enter");

        assert.strictEqual(onChange.lastCall?.args[0], 1);
      });
    });

    module("placeholder", function () {
      test("an explicit placeholder wins", async function (assert) {
        await render(
          <template>
            <Host @multiple={{false}} @placeholder="Pick one" />
          </template>
        );

        assert.strictEqual(placeholderText(), "Pick one");
      });

      test("a read-only category asks to choose", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = true;

        await render(
          <template><Host @multiple={{false}} @readOnly={{2}} /></template>
        );

        assert.strictEqual(
          placeholderText(),
          i18n("category.choose").replace("&hellip;", "…")
        );
      });

      test("allowed uncategorized shows its name", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = true;

        await render(<template><Host @multiple={{false}} /></template>);

        assert.strictEqual(placeholderText(), "uncategorized");
      });

      test("a default composer category still asks to choose", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = false;
        this.siteSettings.default_composer_category = 4;

        await render(<template><Host @multiple={{false}} /></template>);

        assert.strictEqual(
          placeholderText(),
          i18n("category.choose").replace("&hellip;", "…"),
          "the trigger is never left blank"
        );
      });

      test("otherwise it asks to choose", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = false;
        this.siteSettings.default_composer_category = -1;

        await render(<template><Host @multiple={{false}} /></template>);

        assert.strictEqual(
          placeholderText(),
          i18n("category.choose").replace("&hellip;", "…")
        );
      });

      test("a translated none label is the call site's placeholder", async function (assert) {
        I18n.translations[I18n.locale].js.test = { root: "root none label" };
        const label = i18n("test.root");

        await render(
          <template>
            <Host @multiple={{false}} @placeholder={{label}} />
          </template>
        );

        assert.strictEqual(placeholderText(), "root none label");
      });

      test("multiple mode keeps the select's own empty text and name", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = true;

        await render(<template><Host /></template>);

        assert.strictEqual(
          placeholderText(),
          i18n("d_select.add_placeholder"),
          "an empty multiple picker invites adding"
        );
        assert
          .dom("[role='combobox']")
          .hasAria("label", i18n("d_select.label"), "no category names it");
      });
    });

    module("rows", function () {
      test("options show topic counts and selections do not", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9802,
            name: "Counted",
            slug: "counted",
            permission: 1,
            topic_count: 17,
          },
        ]);

        await render(
          <template><Host @multiple={{false}} @value={{9802}} /></template>
        );
        await select().open();
        await select().search("counted");

        assert.dom(".topic-count", optionFor(9802)).hasText("× 17");
        await select().close();
        assert.dom(".topic-count", select().element()).doesNotExist();
      });

      test("single mode shows decoded descriptions, multiple mode does not by default", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9800,
            name: "Entities",
            slug: "entities",
            permission: 1,
            description_text: "baz &quot;bar ‘foo’",
          },
        ]);

        await render(
          <template>
            <div class="single"><Host @multiple={{false}} /></div>
            <div class="multiple"><Host /></div>
          </template>
        );

        await select(".single").open();
        await select(".single").search("entities");
        assert
          .dom(".d-select__option-description", optionFor(9800))
          .hasText('baz "bar ‘foo’');
        await select(".single").close();

        await select(".multiple").open();
        await select(".multiple").search("entities");
        assert
          .dom(".d-select__option-description", optionFor(9800))
          .doesNotExist();
      });

      test("descriptions never render markup and are cut at 200 characters", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9801,
            name: "Markup",
            slug: "markup",
            permission: 1,
            description_text: `<b>bold</b> ${"x".repeat(300)}`,
          },
        ]);

        await render(<template><Host @multiple={{false}} /></template>);
        await select().open();
        await select().search("markup");

        const description = optionFor(9801).querySelector(
          ".d-select__option-description"
        );
        assert.dom("b", description).doesNotExist("no element is created");
        assert.true(description.textContent.trim().startsWith("<b>bold</b>"));
        assert.strictEqual(
          description.textContent.trim().length,
          201,
          "200 characters and an ellipsis"
        );
        assert.true(description.textContent.trim().endsWith("…"));
      });

      test("descriptions go through the category-description-text transformer", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer(
            "category-description-text",
            ({ value, context }) =>
              `transformed-${context.category.id}-${value}`
          )
        );

        await render(
          <template><Host @multiple={{false}} @scope={{1}} /></template>
        );
        await select().open();

        assert
          .dom(".d-select__option-description", optionFor(1))
          .includesText("transformed-1-");
      });

      test("chips show only the category's own badge unless ancestors are asked for", async function (assert) {
        const held = [1002];

        await render(
          <template>
            <div class="plain"><Host @value={{held}} /></div>
            <div class="ancestors"><Host
                @showAncestors={{true}}
                @value={{held}}
              /></div>
          </template>
        );

        assert.deepEqual(
          findAll(".plain .d-select__chip .badge-category__name").map((el) =>
            el.textContent.trim()
          ),
          ["Sub Category"]
        );
        assert.deepEqual(
          findAll(".ancestors .d-select__chip .badge-category__name").map(
            (el) => el.textContent.trim()
          ),
          ["Parent Category", "Sub Category"]
        );
      });
    });

    module("descendants", function () {
      test("multiple mode offers a row for each match with children once the search has two characters", async function (assert) {
        await render(<template><Host /></template>);
        await select().open();

        await select().search("S");
        const matching = Site.current().categories.filter((category) =>
          category.name.toLowerCase().includes("s")
        ).length;
        assert.strictEqual(
          setSize(),
          matching,
          "only category rows for a single character"
        );

        await select().search("Category");
        const rows = findAll("[role='option']");
        assert.strictEqual(
          rows.length,
          5,
          "three categories, two of them with children"
        );
        assert.dom(rows[0]).includesText("Parent Category");
        assert.false(
          /subcategories/i.test(rows[0].textContent),
          "the category row comes first"
        );
        assert.dom(rows[1]).includesText("Parent Category");
        assert.true(
          /subcategories/i.test(rows[1].textContent),
          "its descendants row follows it"
        );
      });

      test("picking the descendants row adds the category and every level below it", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template><Host @emit="ids" @onChange={{onChange}} /></template>
        );
        await select().open();
        await select().search("Parent Category");

        const rows = findAll("[role='option']");
        assert.strictEqual(rows.length, 2);
        await click(rows[1]);

        assert.deepEqual(onChange.lastCall.args[0], [1001, 1002, 1003]);
      });

      test("descendants skip excluded categories", async function (assert) {
        const onChange = sinon.spy();
        const exclude = [1002];

        await render(
          <template>
            <Host @emit="ids" @exclude={{exclude}} @onChange={{onChange}} />
          </template>
        );
        await select().open();
        await select().search("Parent Category");
        await click(findAll("[role='option']")[1]);

        assert.deepEqual(onChange.lastCall.args[0], [1001, 1003]);
      });

      test("single mode never offers descendants rows", async function (assert) {
        await render(<template><Host @multiple={{false}} /></template>);
        await select().open();
        await select().search("Parent Category");

        assert.strictEqual(
          findAll("[role='option']").length,
          2,
          "only the name and parent-name matches"
        );
        assert.deepEqual(optionValues().sort(), ["1001", "1002"]);
      });
    });

    module("lazy loading", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        Site.current().set("lazy_load_categories", true);
        this.table = Site.current().categories.map(serverRow);
      });

      test("browsing pages from the server and searches send the term", async function (assert) {
        const requests = stubServer(this.table);

        await render(<template><Host @permission="create" /></template>);
        await select().open();
        await settled();

        assert.strictEqual(setSize(), this.table.length, "the server count");
        assert.strictEqual(
          requests[0].get("only_postable"),
          "true",
          "postability is decided by the server"
        );

        await select().search("bug");
        await settled();
        assert.strictEqual(requests.at(-1).get("term"), "bug");
        assert.deepEqual(optionValues(), ["1"]);
      });

      test("the list rules are left to the server", async function (assert) {
        const requests = stubServer(this.table);
        const exclude = [1];

        await render(
          <template>
            <Host
              @exclude={{exclude}}
              @subcategories={{false}}
              @uncategorized={{false}}
            />
          </template>
        );
        await select().open();
        await settled();

        assert.deepEqual(requests[0].getAll("reject_category_ids[]"), ["1"]);
        assert.strictEqual(requests[0].get("include_uncategorized"), "false");
        assert.strictEqual(requests[0].get("include_subcategories"), "false");
        assert.false(optionValues().includes("1"), "excluded");
        assert.false(optionValues().includes("17"), "no uncategorized");
        assert.false(optionValues().includes("26"), "no subcategories");
      });

      test("a scope still lists the family one level up", async function (assert) {
        stubServer(this.table);

        await render(
          <template><Host @multiple={{false}} @scope={{26}} /></template>
        );
        await select().open();
        await settled();

        assert.deepEqual(optionValues().sort(), ["2", "26"]);
      });

      test("the read-only category is listed even when the server would not return it", async function (assert) {
        stubServer(this.table.filter((row) => row.id !== 3));

        await render(
          <template>
            <Host
              @multiple={{false}}
              @permission="create"
              @readOnly={{3}}
              @scope={{2}}
            />
          </template>
        );
        await select().open();
        await settled();

        assert.true(optionValues().includes("3"));
        assert.dom(optionFor(3)).hasAttribute("aria-disabled", "true");
      });

      test("a held id the site has not loaded is fetched", async function (assert) {
        pretender.get("/categories/find", () =>
          response({
            categories: [{ id: 9900, name: "Remote", slug: "remote" }],
          })
        );
        const held = [9900];

        await render(<template><Host @value={{held}} /></template>);

        assert.dom(".d-select__chip[data-value='9900']").includesText("Remote");
      });
    });

    module("edge cases", function () {
      test("empty single typeahead exposes the requested placeholder", async function (assert) {
        await render(
          <template>
            <DSelectCategory
              @multiple={{false}}
              @placeholder="Pick one"
              @value={{null}}
            />
          </template>
        );
        assert.strictEqual(
          find(".d-select__input").getAttribute("placeholder"),
          "Pick one",
          "the typeahead input has the placeholder"
        );
      });

      test("descriptions preserve literal markup, decode entities, and truncate after transformation", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9801,
            name: "Markup",
            slug: "markup",
            permission: 1,
            description_text: `<b>bold</b> &quot;${"x".repeat(300)}`,
          },
        ]);
        withPluginApi((api) =>
          api.registerValueTransformer(
            "category-description-text",
            ({ value }) => `prefix ${value}`
          )
        );
        await render(
          <template><DSelectCategory @multiple={{false}} /></template>
        );
        await dSelect().open();
        await dSelect().search("markup");
        const description = find(
          "[data-value='9801'] .d-select__option-description"
        );
        assert
          .dom("b", description)
          .doesNotExist("description markup stays text");
        assert.strictEqual(
          description.textContent.trim(),
          `prefix <b>bold</b> "${"x".repeat(300)}`.slice(0, 200) + "…",
          "decode and cut transformed text"
        );
      });

      test("single searching includes a child matching its parent's name without an action row", async function (assert) {
        await render(
          <template><DSelectCategory @multiple={{false}} /></template>
        );
        await dSelect().open();
        await dSelect().search("Parent Category");
        assert.deepEqual(
          optionValues(),
          ["1001", "1002"],
          "both category matches remain"
        );
        assert.false(
          findAll("[role='option']").some((row) =>
            /all subcategories/i.test(row.textContent)
          ),
          "no bulk actions in single mode"
        );
      });

      test("prioritizing a family still respects uncategorized", async function (assert) {
        this.siteSettings.allow_uncategorized_topics = false;
        await render(
          <template>
            <DSelectCategory @multiple={{false}} @prioritize={{5}} />
          </template>
        );
        await dSelect().open();
        assert.deepEqual(
          optionValues().slice(0, 4),
          ["5", "22", "6", "21"],
          "family first"
        );
        assert.strictEqual(
          Number(find("[role='option']").getAttribute("aria-setsize")),
          Site.current().sortedCategories.filter(
            (category) =>
              category.id !== Site.current().uncategorized_category_id
          ).length,
          "only allowed categories count"
        );
      });

      test("chips omit topic counts and forwarded maximum caps bulk selection", async function (assert) {
        const held = tracked([1001]);
        const onChange = (value) => (held.value = value);
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @maximum={{2}}
              @onChange={{onChange}}
              @value={{held.value}}
            />
          </template>
        );
        assert
          .dom(".d-select__chip .topic-count")
          .doesNotExist("chips do not show counts");
        await dSelect().open();
        await dSelect().search("Parent Category");
        await click(findAll("[role='option']")[1]);
        assert.deepEqual(
          held.value,
          [1001, 1002],
          "bulk additions respect the cap and existing value"
        );
      });

      test("lazy category selection requests subsequent pages in server order", async function (assert) {
        enableVirtualization();
        try {
          Site.current().set("lazy_load_categories", true);
          const pages = [];
          pretender.post("/categories/search", (request) => {
            const page = Number(
              new URLSearchParams(request.requestBody).get("page")
            );
            pages.push(page);
            return response({
              categories_count: 40,
              categories: Array.from(
                { length: page === 1 ? 25 : 15 },
                (_, index) => ({
                  id: 9900 + (page - 1) * 25 + index,
                  name: `Remote ${page}-${index}`,
                  slug: `remote-${page}-${index}`,
                  permission: 1,
                  has_children: false,
                })
              ),
              ancestors: [],
            });
          });
          await render(<template><DSelectCategory /></template>);
          await dSelect().open();
          await settled();
          await dSelect().search("Remote");
          await settled();
          const list = find(".d-virtual-list");
          list.scrollTop = list.scrollHeight;
          await triggerEvent(list, "scroll");
          await settledAfterFrame();
          assert.true(pages.includes(2), "scroll loads the next page");
          assert.strictEqual(
            Number(find("[role='option']").getAttribute("aria-setsize")),
            40,
            "count stays global"
          );
        } finally {
          disableVirtualization();
        }
      });

      test("a replaceable synchronous source emits its site's Category", async function (assert) {
        const category = Category.findById(1);
        const load = () => [{ id: category.id, name: category.name }];
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectCategory
              @load={{load}}
              @multiple={{false}}
              @onChange={{onChange}}
            />
          </template>
        );
        await dSelect().open();
        await click("[role='option'][data-value='1']");
        assert.strictEqual(
          onChange.lastCall?.args[0],
          category,
          "source replacement preserves category emission"
        );
      });

      test("uncategorized is ignored when the site has none", async function (assert) {
        Site.current().set("uncategorized_category_id", null);
        await render(
          <template>
            <DSelectCategory @multiple={{false}} @uncategorized={{true}} />
          </template>
        );
        assert
          .dom(".d-select__input")
          .hasAttribute(
            "placeholder",
            "Category…",
            "empty control asks to choose"
          );
      });

      test("multiple noneLabel clears every held category", async function (assert) {
        const value = [1, 2];
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectCategory
              @noneLabel="Any category"
              @onChange={{onChange}}
              @value={{value}}
            />
          </template>
        );
        await dSelect().open();
        const clear = findAll("[role='option']").find((row) =>
          row.textContent.includes("Any category")
        );
        assert.strictEqual(
          clear?.getAttribute("role"),
          "option",
          "the selectable clear row is present"
        );
        await click(clear);
        assert.deepEqual(
          onChange.lastCall?.args[0],
          [],
          "the row clears all values"
        );
      });

      test("lazy descendants walk every level and skip excluded categories", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        const rows = [
          {
            id: 9900,
            name: "Branch",
            slug: "branch",
            permission: 1,
            has_children: true,
          },
          {
            id: 9901,
            name: "Child",
            slug: "child",
            permission: 1,
            parent_category_id: 9900,
            has_children: true,
          },
          {
            id: 9902,
            name: "Deep",
            slug: "deep",
            permission: 1,
            parent_category_id: 9901,
            has_children: false,
          },
        ];
        const parents = [];
        pretender.post("/categories/search", (request) => {
          const params = new URLSearchParams(request.requestBody);
          const parent = Number(params.get("parent_category_id"));
          if (parent) {
            parents.push(parent);
          }
          const categories = parent
            ? rows.filter((row) => row.parent_category_id === parent)
            : [rows[0]];
          return response({
            categories_count: categories.length,
            categories,
            ancestors: [],
          });
        });
        const exclude = [9901];
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @exclude={{exclude}}
              @onChange={{onChange}}
            />
          </template>
        );
        await dSelect().open();
        await dSelect().search("Branch");
        await click(findAll("[role='option']")[1]);
        assert.deepEqual(
          onChange.lastCall?.args[0],
          [9900, 9902],
          "all levels, skipping exclusions"
        );
        assert.deepEqual(
          parents,
          [9900, 9901],
          "walk continues through excluded ancestors"
        );
      });

      test("a hand pick supersedes a pending lazy descendant walk without a late emission", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        let release;
        let asked = false;
        const pending = new Promise((resolve) => (release = resolve));
        pretender.post("/categories/search", (request) => {
          const params = new URLSearchParams(request.requestBody);
          if (params.get("parent_category_id") === "9900") {
            asked = true;
            return pending;
          }
          return response({
            categories_count: 1,
            categories: [
              {
                id: 9900,
                name: "Branch",
                slug: "branch",
                permission: 1,
                has_children: true,
              },
            ],
            ancestors: [],
          });
        });
        const value = tracked([]);
        const changes = [];
        const onChange = (next) => {
          changes.push(next);
          value.value = next;
        };
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @onChange={{onChange}}
              @value={{value.value}}
            />
          </template>
        );
        await dSelect().open();
        await dSelect().search("Branch");
        const bulkPick = click(findAll("[role='option']")[1]);
        await waitUntil(() => asked);
        const handPick = click("[role='option'][data-value='9900']");
        try {
          await waitUntil(() => changes.length > 0);
        } finally {
          release(
            response({
              categories_count: 1,
              categories: [
                {
                  id: 9901,
                  name: "Late child",
                  slug: "late-child",
                  parent_category_id: 9900,
                  permission: 1,
                  has_children: false,
                },
              ],
              ancestors: [],
            })
          );
          await Promise.all([bulkPick, handPick]);
        }
        assert.deepEqual(changes, [[9900]], "only the hand pick emits");
      });

      test("a lazy read-only row does not inflate the server's set size", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        const table = Array.from({ length: 40 }, (_, index) => ({
          id: 9900 + index,
          name: `Remote ${index}`,
          slug: `remote-${index}`,
          permission: 1,
          has_children: false,
        }));
        Site.current().updateCategories([table[0]]);
        pretender.post("/categories/search", (request) => {
          const params = new URLSearchParams(request.requestBody);
          const rejected = params.getAll("reject_category_ids[]").map(Number);
          const rows = table.filter((row) => !rejected.includes(row.id));
          const page = Number(params.get("page"));
          return response({
            categories_count: rows.length,
            categories: rows.slice((page - 1) * 25, page * 25),
            ancestors: [],
          });
        });
        await render(
          <template><DSelectCategory @readOnly={{9900}} /></template>
        );
        await dSelect().open();
        assert
          .dom("[role='option'][data-value='9900']")
          .hasAttribute(
            "aria-disabled",
            "true",
            "the read-only row is disabled"
          );
        assert.strictEqual(
          Number(find("[role='option']").getAttribute("aria-setsize")),
          40,
          "the read-only row is counted once"
        );
      });

      test("fixed creation positions keep the site's order", async function (assert) {
        Site.current().updateCategories([
          {
            id: 9900,
            name: "Quiet first",
            slug: "quiet-first",
            permission: 1,
            topic_count: 1,
          },
          {
            id: 9901,
            name: "Busy second",
            slug: "busy-second",
            permission: 1,
            topic_count: 1000,
          },
        ]);
        Site.current().set("categories", [
          Category.findById(9900),
          Category.findById(9901),
        ]);
        this.siteSettings.fixed_category_positions_on_create = true;
        await render(<template><DSelectCategory /></template>);
        await dSelect().open();
        assert.deepEqual(
          optionValues(),
          ["9900", "9901"],
          "activity does not override fixed positions"
        );
      });

      test("lazy browsing resolves an unloaded read-only category by id", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        const remote = [
          serverRow(Category.findById(2)),
          {
            id: 9900,
            name: "Remote read only",
            slug: "remote-read-only",
            permission: null,
          },
        ];
        pretender.get("/categories/find", (request) => {
          const ids = [request.queryParams.ids].flat().map(Number);
          return response({
            categories: remote.filter(({ id }) => ids.includes(id)),
          });
        });
        pretender.post("/categories/search", () =>
          response({ categories_count: 0, categories: [], ancestors: [] })
        );
        await render(
          <template>
            <DSelectCategory
              @permission="create"
              @readOnly={{9900}}
              @scope={{2}}
            />
          </template>
        );
        await dSelect().open();
        assert
          .dom("[role='option'][data-value='9900']")
          .hasAttribute(
            "aria-disabled",
            "true",
            "the unloaded read-only category is listed"
          );
        assert
          .dom("[role='option'][data-value='9900']")
          .includesText("Remote read only", "the resolved name is visible");
      });

      test("an ordinary pick does not reload the category source", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        let requests = 0;
        pretender.post("/categories/search", () => {
          requests++;
          return response({
            categories_count: 2,
            categories: [
              { id: 1, name: "bug", permission: 1, has_children: false },
              { id: 2, name: "feature", permission: 1, has_children: false },
            ],
            ancestors: [],
          });
        });
        const value = tracked([]);
        const onChange = (next) => (value.value = next);
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @onChange={{onChange}}
              @value={{value.value}}
            />
          </template>
        );
        await dSelect().open();
        await click("[role='option'][data-value='1']");
        assert.deepEqual(
          value.value,
          [1],
          "the pick updates the controlled value"
        );
        assert.strictEqual(
          requests,
          1,
          "a pick leaves the existing page intact"
        );
      });

      test("only held excluded membership reloads the category list", async function (assert) {
        Site.current().set("lazy_load_categories", true);
        const requests = [];
        pretender.post("/categories/search", (request) => {
          const rejected = new URLSearchParams(request.requestBody).getAll(
            "reject_category_ids[]"
          );
          requests.push(rejected);
          const categories = [
            { id: 1, name: "bug", permission: 1, has_children: false },
            { id: 2, name: "feature", permission: 1, has_children: false },
          ].filter((row) => !rejected.includes(String(row.id)));
          return response({
            categories_count: categories.length,
            categories,
            ancestors: [],
          });
        });
        const value = tracked([1]);
        const exclude = [1];
        const onChange = (next) => (value.value = next);
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @exclude={{exclude}}
              @onChange={{onChange}}
              @value={{value.value}}
            />
          </template>
        );
        await dSelect().open();
        await click("[role='option'][data-value='2']");
        assert.strictEqual(
          requests.length,
          1,
          "an unrelated selection does not reload"
        );
        await dSelect().remove(1);
        assert.deepEqual(
          requests,
          [[], ["1"]],
          "removing the held exception reloads with that id excluded"
        );
        assert
          .dom("[role='option'][data-value='1']")
          .doesNotExist("the excluded category is no longer listed");
      });

      test("local category lists follow a refreshed site collection", async function (assert) {
        await render(<template><DSelectCategory /></template>);
        await dSelect().open();
        Site.current().updateCategories([
          { id: 99001, name: "Fresh category", slug: "fresh", permission: 1 },
        ]);
        await settled();
        assert
          .dom("[role='option'][data-value='99001']")
          .exists("a new category appears in the open list");
        await dSelect().search("Fresh");
        assert.deepEqual(
          optionValues(),
          ["99001"],
          "search uses the refreshed collection"
        );
      });

      test("local descendant actions keep their count and adjacency across pages", async function (assert) {
        enableVirtualization();
        try {
          const categories = Array.from({ length: 61 }, (_, index) => {
            const id = 99000 + index * 2;
            return [
              Category.create({
                id,
                name: `Paged family ${index}`,
                permission: 1,
              }),
              Category.create({
                id: id + 1,
                name: `Paged family ${index} child`,
                parent_category_id: id,
                permission: 1,
              }),
            ];
          }).flat();
          Site.current().set("categories", categories);
          const onChange = sinon.spy();
          await render(
            <template>
              <DSelectCategory @emit="ids" @onChange={{onChange}} />
            </template>
          );
          await dSelect().open();
          await dSelect().search("Paged family");
          assert.dom("[role='option']").hasAttribute("aria-setsize", "183");
          for (let scroll = 0; scroll < 8; scroll++) {
            const list = find(".d-virtual-list");
            list.scrollTop = list.scrollHeight;
            await triggerEvent(list, "scroll");
            await settledAfterFrame();
          }
          const actionRow = find("[data-value='category-descendants-99120']");
          assert.strictEqual(
            actionRow.previousElementSibling.dataset.value,
            "99120"
          );
          assert.strictEqual(
            actionRow.nextElementSibling.dataset.value,
            "99121"
          );
          await click(actionRow);
          assert.deepEqual(onChange.lastCall.args[0], [99120, 99121]);
        } finally {
          disableVirtualization();
        }
      });

      test("mounts a window of the local list and reports the full matching count", async function (assert) {
        enableVirtualization();
        try {
          const categories = setPagedCategories();
          await render(<template><DSelectCategory /></template>);
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
            <template><DSelectCategory @onChange={{onChange}} /></template>
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
          await render(<template><DSelectCategory /></template>);
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
