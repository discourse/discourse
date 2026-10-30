import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect as SelectDriver } from "discourse/tests/helpers/d-select-helper";
import DSelectTagFilter, {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import { i18n } from "discourse-i18n";

const ROWS = [
  { id: 1, name: "bug", text: "bug", count: 4 },
  { id: 2, name: "ui", text: "ui", count: 2 },
  { id: 3, name: "perf", text: "perf", count: 1 },
];

/** Stubs tag search, recording each request's query params. */
function stubSearch(rows = ROWS, extra = {}) {
  const requests = [];
  // Name-only held or blocked tags are resolved to ids through the list endpoint.
  pretender.get("/tags/list.json", () => response({ list_tags: [] }));
  pretender.get("/tags/filter/search", (request) => {
    requests.push(request.queryParams);
    const q = request.queryParams.q ?? "";
    return response({
      results: rows.filter((row) => row.name.includes(q)),
      ...extra,
    });
  });
  return requests;
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

const TOP_TAGS = [
  { id: 3, name: "zeta", slug: "zeta", count: 1 },
  { id: 1, name: "alpha", slug: "alpha", count: 5 },
];

module(
  "Integration | ui-kit | select | recipes | DSelectTagFilter",
  function (hooks) {
    setupRenderingTest(hooks);

    module("shortcuts and values", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tags_in_filter_list = 30;
        this.siteSettings.max_tag_search_results = 5;
        this.siteSettings.tags_sort_alphabetically = false;
        getOwner(this).lookup("service:site").set("top_tags", TOP_TAGS);
        this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
        this.routeTo = sinon.stub(DiscourseURL, "routeTo");
      });

      test("suppressFooter: a single filter with every tag listed has no footer", async function (assert) {
        await render(<template><DSelectTagFilter /></template>);
        await click(".d-select__trigger");

        assert.dom(optionNamed("zeta")).exists("the panel is open");
        assert
          .dom(".d-select__footer")
          .doesNotExist("no empty footer region below the list");
      });

      test("suppressFooter: a single filter with more tags than listed shows its hint", async function (assert) {
        this.siteSettings.max_tags_in_filter_list = 1;
        await render(<template><DSelectTagFilter /></template>);
        await click(".d-select__trigger");

        assert
          .dom(".d-select__footer")
          .hasText(i18n("select_kit.components.filter_for_more"));
      });

      test("suppressFooter: a single filter keeps its caller's footer", async function (assert) {
        await render(
          <template>
            <DSelectTagFilter>
              <:footer>
                <span class="custom-footer">Footer</span>
              </:footer>
            </DSelectTagFilter>
          </template>
        );
        await click(".d-select__trigger");

        assert.dom(".d-select__footer .custom-footer").exists();
      });

      test("suppressFooter: a multiple filter without a caller footer has no footer", async function (assert) {
        stubSearch();
        const onChange = () => {};
        await render(
          <template>
            <DSelectTagFilter @multiple={{true}} @onChange={{onChange}} />
          </template>
        );
        await click(".d-select__trigger");

        assert.dom(optionNamed("bug")).exists("the panel is open");
        assert
          .dom(".d-select__footer")
          .doesNotExist("no empty footer region below the list");
      });

      test("searchIcon: a single filter shows the search icon in its panel", async function (assert) {
        await render(<template><DSelectTagFilter /></template>);
        await click(".d-select__trigger");

        assert.dom(".d-select__panel .d-icon-magnifying-glass").exists();
      });

      test("tag drop parity: the panel is at least 16em wide", async function (assert) {
        await render(
          <template>
            <div style="width: 80px"><DSelectTagFilter /></div>
          </template>
        );
        await click(".d-select__trigger");

        const content = find(".d-select__content");
        const em = parseFloat(getComputedStyle(content).fontSize);
        assert.true(
          content.offsetWidth >= 16 * em - 0.5,
          `the panel is ${content.offsetWidth / em}em wide`
        );
      });

      test("tag drop parity: a long tag keeps its count on its line", async function (assert) {
        getOwner(this)
          .lookup("service:site")
          .set("top_tags", [
            {
              id: 9,
              name: "differential-equations-and-more-analysis",
              slug: "differential-equations-and-more-analysis",
              count: 5,
            },
          ]);
        await render(<template><DSelectTagFilter /></template>);
        await click(".d-select__trigger");

        const row = optionNamed("differential-equations");
        const tag = row.querySelector(".discourse-tag").getBoundingClientRect();
        const count = row.querySelector(".discourse-tag-count");
        assert.dom(count).hasText("x5", "the count reads as one word");
        const box = count.getBoundingClientRect();
        assert.true(
          Math.abs(box.top + box.height / 2 - (tag.top + tag.height / 2)) <
            tag.height / 2,
          "the count sits on the tag's line"
        );
        assert.true(
          box.right <= row.getBoundingClientRect().right,
          "the count stays inside the row"
        );
      });

      test("tag drop parity: a held tag or untagged filter colors the trigger", async function (assert) {
        const tag = { id: 1, name: "alpha", slug: "alpha" };
        await render(
          <template>
            <div class="list-controls">
              <span
                class="probe"
                style="color: var(--d-nav-border-color--active)"
              >
                probe
              </span>
              <div class="all"><DSelectTagFilter /></div>
              <div class="tagged"><DSelectTagFilter @value={{tag}} /></div>
              <div class="untagged"><DSelectTagFilter
                  @value={{NO_TAG_ID}}
                /></div>
            </div>
          </template>
        );

        const active = getComputedStyle(find(".probe")).color;
        const style = (selector) => getComputedStyle(find(selector));
        assert.strictEqual(style(".tagged .d-select").color, active);
        assert.strictEqual(style(".tagged .d-select").borderTopColor, active);
        assert.strictEqual(style(".untagged .d-select").color, active);
        assert.notStrictEqual(
          style(".all .d-select").borderTopColor,
          active,
          "all tags is not a filter"
        );
      });

      test("tag drop parity: the topic-list trigger rules, hover included, reach the trigger", async function (assert) {
        await render(
          <template>
            <div class="uc-modernize-foundation-theme">
              <div class="list-controls"><DSelectTagFilter /></div>
            </div>
          </template>
        );

        const selectors = [];
        const collect = (rules) => {
          for (const rule of rules) {
            if (rule.cssRules) {
              collect(rule.cssRules);
            }
            if (rule.selectorText?.includes("tag-drop")) {
              selectors.push(...rule.selectorText.split(","));
            }
          }
        };
        for (const sheet of document.styleSheets) {
          try {
            collect(sheet.cssRules);
          } catch {
            // Cross-origin sheets cannot be read.
          }
        }
        const trigger = find(".d-select.tag-drop");
        const matching = (hover) =>
          selectors.filter(
            (selector) =>
              selector.includes(".list-controls") &&
              selector.includes(":hover") === hover &&
              trigger.matches(selector.replace(":hover", "").trim())
          );

        assert.true(
          matching(false).length > 0,
          "the base trigger rule applies"
        );
        assert.true(matching(true).length > 0, "the hover rule applies");
      });

      test("tag drop parity: the empty trigger draws its text and caret like the legacy header", async function (assert) {
        await render(
          <template>
            <div class="list-controls">
              <span class="high" style="color: var(--primary-high)">high</span>
              <DSelectTagFilter />
            </div>
            <div class="uc-modernize-foundation-theme">
              <div class="list-controls">
                <span class="plain" style="color: var(--primary)">plain</span>
                <DSelectTagFilter />
              </div>
            </div>
          </template>
        );

        const color = (selector) => getComputedStyle(find(selector)).color;
        for (const part of [".d-select__placeholder", ".d-select__caret"]) {
          assert.strictEqual(
            color(`.list-controls > .d-select ${part}`),
            color(".high"),
            part
          );
          assert.strictEqual(
            color(`.uc-modernize-foundation-theme .d-select ${part}`),
            color(".plain"),
            `${part}, modernized`
          );
        }
      });

      test("tag drop parity: the open trigger shows the focus ring", async function (assert) {
        await render(
          <template>
            <div class="list-controls">
              <span class="probe" style="color: var(--d-input-focused-color)">
                probe
              </span>
              <DSelectTagFilter />
            </div>
          </template>
        );
        await click(".d-select__trigger");

        const focused = getComputedStyle(find(".probe")).color;
        const trigger = getComputedStyle(find(".d-select.tag-drop"));
        assert.strictEqual(trigger.outlineStyle, "solid");
        assert.strictEqual(trigger.outlineColor, focused);
        assert.strictEqual(trigger.borderTopColor, focused);
      });

      test("tag drop parity: the modernized open trigger fills instead of ringing", async function (assert) {
        await render(
          <template>
            <div class="uc-modernize-foundation-theme">
              <div class="list-controls">
                <span class="fill" style="color: var(--primary-100)">
                  fill
                </span>
                <span class="edge" style="color: var(--primary-300)">
                  edge
                </span>
                <DSelectTagFilter />
              </div>
            </div>
          </template>
        );
        await click(".d-select__trigger");

        const trigger = getComputedStyle(find(".d-select.tag-drop"));
        assert.strictEqual(
          trigger.backgroundColor,
          getComputedStyle(find(".fill")).color
        );
        assert.strictEqual(
          trigger.borderTopColor,
          getComputedStyle(find(".edge")).color
        );
        assert.strictEqual(trigger.outlineStyle, "none");
      });

      test("exports the shortcut values", function (assert) {
        assert.strictEqual(ALL_TAGS_ID, "all-tags");
        assert.strictEqual(NO_TAG_ID, "no-tags");
      });

      test("single mode keeps the legacy drop classes", async function (assert) {
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(
          <template>
            <div class="none"><DSelectTagFilter /></div>
            <div class="tagged"><DSelectTagFilter @value={{tag}} /></div>
          </template>
        );

        assert.dom(".none .d-select").hasClass("tag-drop");
        assert.dom(".none .d-select").hasClass("tag_all");
        assert.dom(".tagged .d-select").hasClass("tag-alpha");
      });

      test("shortcuts first, then top tags; picks emit rows and never navigate", async function (assert) {
        const onChange = sinon.spy();
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(
          <template>
            <DSelectTagFilter @onChange={{onChange}} @value={{tag}} />
          </template>
        );
        await click(".d-select__trigger");

        const names = findAll("[role='option']").map((row) =>
          row.textContent.trim()
        );
        assert.true(names[0].includes(i18n("tagging.selector_remove_filter")));
        assert.true(names[1].includes(i18n("tagging.selector_no_tags")));
        assert.true(names[2].includes("zeta"));

        await click(optionNamed("zeta"));
        assert.deepEqual(
          onChange.lastCall.args[0],
          { id: 3, name: "zeta", slug: "zeta", count: 1 },
          "the full row"
        );
        assert.false(this.routeToUrl.called, "no navigation");
        assert.false(this.routeTo.called, "no navigation");
      });

      test("the shortcuts emit their ids", async function (assert) {
        const onChange = sinon.spy();
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(
          <template>
            <DSelectTagFilter @onChange={{onChange}} @value={{tag}} />
          </template>
        );
        await click(".d-select__trigger");
        await click(optionNamed(i18n("tagging.selector_remove_filter")));
        assert.strictEqual(onChange.lastCall.args[0], ALL_TAGS_ID);

        await click(".d-select__trigger");
        await click(optionNamed(i18n("tagging.selector_no_tags")));
        assert.strictEqual(onChange.lastCall.args[0], NO_TAG_ID);
      });

      test("a tag model value keeps its name on the trigger", async function (assert) {
        const tag = getOwner(this)
          .lookup("service:store")
          .createRecord("tag", { id: 1, name: "alpha", slug: "alpha" });

        await render(<template><DSelectTagFilter @value={{tag}} /></template>);

        assert
          .dom(".d-select")
          .hasAttribute("data-name", "alpha", "the model's name is read");
        assert.dom(".d-select").hasClass("tag-alpha");
      });

      test("a tag named none reads as untagged", async function (assert) {
        const untagged = { name: "none" };

        await render(
          <template><DSelectTagFilter @value={{untagged}} /></template>
        );

        assert
          .dom(".d-select")
          .hasAttribute("data-name", i18n("tagging.selector_no_tags"));
      });

      test("multiple mode holds tags in order, by identity, with the intersection classes", async function (assert) {
        const requests = stubSearch();
        const onChange = sinon.spy();
        const main = { id: 2, name: "ui", slug: "ui" };
        const held = [main];

        await render(
          <template>
            <DSelectTagFilter
              @multiple={{true}}
              @onChange={{onChange}}
              @value={{held}}
            />
          </template>
        );

        assert.dom(".d-select").hasClass("tags-intersection-chooser");
        assert.dom(".d-select").hasClass("mini-tag-chooser");

        await click(".d-select__trigger");
        assert.strictEqual(
          optionNamed(i18n("tagging.selector_no_tags")),
          undefined,
          "no shortcuts"
        );
        assert.strictEqual(
          requests.at(-1).filterForInput,
          "true",
          "searches tags usable on topics"
        );

        await click(optionNamed("bug"));
        const emitted = onChange.lastCall.args[0];
        assert.strictEqual(emitted[0], main, "the held tag keeps its identity");
        assert.strictEqual(emitted[1].name, "bug");
        assert.false(this.routeTo.called, "no navigation");
      });

      test("@items filters a local list", async function (assert) {
        const requests = stubSearch();
        const items = [
          { id: 7, name: "local-one" },
          { id: 8, name: "local-two" },
        ];

        await render(
          <template><DSelectTagFilter @items={{items}} /></template>
        );
        await click(".d-select__trigger");

        assert.notStrictEqual(optionNamed("local-one"), undefined);
        assert.strictEqual(requests.length, 0, "no search request");
      });
    });

    module("texts", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        resetTagSourceCache();
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tags_in_filter_list = 30;
        this.siteSettings.max_tag_search_results = 5;
        this.site.set("top_tags", TOP_TAGS);
      });

      test("@texts names the filter and sets its empty text, in both modes", async function (assert) {
        stubSearch();
        const held = [];

        await render(
          <template>
            <div class="single"><DSelectTagFilter
                @texts={{hash ariaLabel="Narrow topics" placeholder="any tag"}}
              /></div>
            <div class="multiple"><DSelectTagFilter
                @multiple={{true}}
                @texts={{hash ariaLabel="Narrow topics" placeholder="any tag"}}
                @value={{held}}
              /></div>
          </template>
        );

        assert.dom(".single .d-select").hasAria("label", "Narrow topics");
        assert.dom(".single .d-select__placeholder").hasText("any tag");
        assert
          .dom(".multiple [role='combobox']")
          .hasAria("label", "Narrow topics")
          .hasAttribute("placeholder", "any tag");
      });

      test("a customization renames the shortcuts, held or listed", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forKind("select-tag-filter", (spec) =>
              spec.options(() => ({
                texts: { removeFilter: "Show everything", noTags: "Untagged" },
              }))
            )
          )
        );
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(
          <template>
            <div class="untagged"><DSelectTagFilter
                @value={{NO_TAG_ID}}
              /></div>
            <div class="tagged"><DSelectTagFilter @value={{tag}} /></div>
          </template>
        );

        assert
          .dom(".untagged .d-select")
          .hasAttribute("data-name", "Untagged", "the held shortcut");
        await click(".tagged .d-select__trigger");
        assert.dom(optionNamed("Show everything")).exists();
        assert.dom(optionNamed("Untagged")).exists();
      });

      test("a customization rewords the hint for more tags", async function (assert) {
        this.siteSettings.max_tags_in_filter_list = 1;
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forKind("select-tag-filter", (spec) =>
              spec.options(() => ({
                texts: { filterForMore: "Type to find more" },
              }))
            )
          )
        );

        await render(<template><DSelectTagFilter /></template>);
        await click(".d-select__trigger");

        assert.dom(".d-select__footer").hasText("Type to find more");
      });

      test("a multiple filter keeps its own prompt in a category with an unmet required group", async function (assert) {
        stubSearch(ROWS, {
          required_tag_group: {
            name: "Platform",
            min_count: 2,
            remaining_count: 2,
          },
        });
        const empty = [];
        const held = [{ id: 1, name: "bug" }];

        await render(
          <template>
            <div class="empty"><DSelectTagFilter
                @categoryId={{7}}
                @multiple={{true}}
                @value={{empty}}
              /></div>
            <div class="held"><DSelectTagFilter
                @categoryId={{7}}
                @multiple={{true}}
                @value={{held}}
              /></div>
          </template>
        );
        await new SelectDriver(".empty .d-select").open();
        await new SelectDriver(".empty .d-select").close();
        await new SelectDriver(".held .d-select").open();

        assert
          .dom(".empty [role='combobox']")
          .hasAttribute("placeholder", i18n("tagging.selector_tags"));
        assert
          .dom(".held [role='combobox']")
          .hasAttribute("placeholder", i18n("tagging.add_more_tags"));
      });

      test("a kind customization reaches the tag counts in both modes", async function (assert) {
        stubSearch();
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forKind("select-tag-filter", (spec) =>
              spec.options(() => ({
                texts: { tagCount: ({ count }) => `${count} uses` },
              }))
            )
          )
        );
        const held = [];

        await render(
          <template>
            <div class="single"><DSelectTagFilter /></div>
            <div class="multiple"><DSelectTagFilter
                @multiple={{true}}
                @value={{held}}
              /></div>
          </template>
        );
        await click(".single .d-select__trigger");
        assert.dom(".sr-only", optionNamed("alpha")).hasText("5 uses");
        await new SelectDriver(".single .d-select").close();

        await new SelectDriver(".multiple .d-select").open();
        assert.dom(".sr-only", optionNamed("bug")).hasText("4 uses");
      });
    });

    module("name, empty level and caret", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_in_filter_list = 30;
        this.siteSettings.max_tag_search_results = 5;
        this.site.set("top_tags", TOP_TAGS);
      });

      test("@ariaLabelledBy names it after a visible caption, single or multiple", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <span id="filter-caption">Narrow by tag</span>
            <div class="single"><DSelectTagFilter
                @ariaLabelledBy="filter-caption"
              /></div>
            <div class="multiple"><DSelectTagFilter
                @ariaLabelledBy="filter-caption"
                @multiple={{true}}
              /></div>
          </template>
        );

        assert.strictEqual(
          accessibleName(find(".single .d-select")),
          "Narrow by tag",
          "the single drop's trigger"
        );
        assert.strictEqual(
          accessibleName(find(".multiple [role='combobox']")),
          "Narrow by tag",
          "the multiple drop's field"
        );
      });

      test("an empty filter is named for what it filters and shows tags as its placeholder", async function (assert) {
        await render(
          <template>
            <div class="none"><DSelectTagFilter /></div>
            <div class="all"><DSelectTagFilter @value={{ALL_TAGS_ID}} /></div>
          </template>
        );

        for (const scope of [".none", ".all"]) {
          const root = find(`${scope} .d-select`);
          assert.strictEqual(
            root.getAttribute("aria-label"),
            i18n("tagging.filter_by_tags_label"),
            scope
          );
          assert.strictEqual(root.dataset.value, "", `${scope} holds nothing`);
          assert
            .dom(".d-select__placeholder", root)
            .hasText(i18n("tagging.selector_tags"), `${scope} shows tags`);
        }
      });

      test("a held filter follows the name", async function (assert) {
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(
          <template>
            <div class="tagged"><DSelectTagFilter @value={{tag}} /></div>
            <div class="untagged"><DSelectTagFilter
                @value={{NO_TAG_ID}}
              /></div>
          </template>
        );

        assert
          .dom(".tagged .d-select")
          .hasAria("label", `${i18n("tagging.filter_by_tags_label")}, alpha`);
        assert
          .dom(".untagged .d-select")
          .hasAria(
            "label",
            `${i18n("tagging.filter_by_tags_label")}, ${i18n(
              "tagging.selector_no_tags"
            )}`
          );
        assert.strictEqual(
          find(".untagged .d-select").dataset.value,
          NO_TAG_ID,
          "no tags is a held filter"
        );
      });

      test("the intersection filter is named for what it filters", async function (assert) {
        stubSearch();
        const held = [];

        await render(
          <template>
            <DSelectTagFilter @multiple={{true}} @value={{held}} />
          </template>
        );

        assert
          .dom("[role='combobox']")
          .hasAria("label", i18n("tagging.filter_by_tags_label"))
          .hasAttribute(
            "placeholder",
            i18n("tagging.selector_tags"),
            "not the composer's text"
          );
      });

      test("a call site or a customization can replace the empty text", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forIdentifier("custom-tags", (spec) =>
              spec.options(() => ({ texts: { placeholder: "any label" } }))
            );
          })
        );

        await render(
          <template>
            <div class="own"><DSelectTagFilter
                @texts={{hash placeholder="any tag"}}
              /></div>
            <div class="custom"><DSelectTagFilter
                @identifier="custom-tags"
              /></div>
          </template>
        );

        assert.dom(".own .d-select__placeholder").hasText("any tag");
        assert.dom(".custom .d-select__placeholder").hasText("any label");
      });

      test("the caret points right while closed and down while open", async function (assert) {
        await render(<template><DSelectTagFilter /></template>);

        assert.dom(".d-select__caret").hasClass("d-icon-angle-right");
        await click(".d-select__trigger");
        assert.dom(".d-select__caret").hasClass("d-icon-angle-down");
      });

      test("a customization can replace the caret", async function (assert) {
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-tag-filter", (spec) =>
              spec.options(() => ({
                caretIcon: { open: "chevron-up", closed: "chevron-right" },
              }))
            );
          })
        );

        await render(<template><DSelectTagFilter /></template>);

        assert.dom(".d-select__caret").hasClass("d-icon-chevron-right");
        await click(".d-select__trigger");
        assert.dom(".d-select__caret").hasClass("d-icon-chevron-up");
      });

      test("the shortcuts lead browsing and leave a search", async function (assert) {
        stubSearch();
        const tag = { id: 1, name: "alpha", slug: "alpha" };

        await render(<template><DSelectTagFilter @value={{tag}} /></template>);
        await click(".d-select__trigger");

        const names = findAll("[role='option']").map((row) =>
          row.textContent.trim()
        );
        assert.deepEqual(names.slice(0, 2), [
          i18n("tagging.selector_remove_filter"),
          i18n("tagging.selector_no_tags"),
        ]);

        await fillIn(".d-select__panel input", "bu");
        assert.notStrictEqual(optionNamed("bug"), undefined, "the match");
        assert.strictEqual(
          optionNamed(i18n("tagging.selector_remove_filter")),
          undefined,
          "no shortcut in a search"
        );
        assert.strictEqual(
          optionNamed(i18n("tagging.selector_no_tags")),
          undefined,
          "no shortcut in a search"
        );
      });
    });

    module("shortcut changes and search", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_in_filter_list = 30;
        this.siteSettings.max_tag_search_results = 5;
        this.site.set("top_tags", TOP_TAGS);
      });

      test("the shortcuts follow a changed tag", async function (assert) {
        const currentTag = tracked(null);
        await render(
          <template><DSelectTagFilter @value={{currentTag.value}} /></template>
        );
        const select = new SelectDriver();
        await select.open();
        assert.strictEqual(
          optionNamed(i18n("tagging.selector_remove_filter")),
          undefined,
          "no tag means no filter to remove"
        );
        await select.close();
        currentTag.value = { id: 1, name: "alpha", slug: "alpha" };
        await settled();
        await select.open();
        assert.notStrictEqual(
          optionNamed(i18n("tagging.selector_remove_filter")),
          undefined,
          "the changed tag adds the remove shortcut"
        );
      });

      test("typing searches all tags", async function (assert) {
        const requests = stubSearch();
        await render(<template><DSelectTagFilter /></template>);
        await new SelectDriver().search("bu");
        assert.strictEqual(
          requests.at(-1).q,
          "bu",
          "the query reaches tag search"
        );
        assert.strictEqual(
          requests.at(-1).filterForInput,
          undefined,
          "search bypasses input restrictions"
        );
        assert.notStrictEqual(
          optionNamed("bug"),
          undefined,
          "the result renders"
        );
      });
    });

    module("local items, caps and clearing", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        resetTagSourceCache();
        this.site.set("can_create_tag", true);
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tag_search_results = 5;
        this.siteSettings.max_tag_length = 30;
        this.siteSettings.force_lowercase_tags = true;
        pretender.get("/tags/list.json", () =>
          response({ list_tags: [{ id: 3, name: "excluded" }] })
        );
        pretender.get("/tags/filter/search", () =>
          response({
            results: [
              {
                id: 1,
                name: "戦略",
                original_name: "strategy",
                text: "戦略",
                count: 9,
              },
              { id: 2, name: "other", text: "other" },
              { id: 3, name: "除外", original_name: "excluded", text: "除外" },
            ],
          })
        );
      });

      test("multiple filters use local items, enforce the site cap and never create", async function (assert) {
        this.siteSettings.max_tags_per_topic = 1;
        const requests = sinon.spy();
        pretender.get("/tags/filter/search", () => {
          requests();
          return response({ results: [] });
        });
        const items = [
          { id: 1, name: "first" },
          { id: 2, name: "second" },
        ];
        const held = [items[0]];
        await render(
          <template>
            <DSelectTagFilter
              @items={{items}}
              @multiple={{true}}
              @value={{held}}
            />
          </template>
        );
        await click(".d-select__trigger");
        const second = optionNamed("second");
        assert
          .dom(second)
          .hasAttribute("aria-disabled", "true", "the site cap applies");
        await fillIn("[role='combobox']", "unknown");
        assert
          .dom("[role='option'].--create")
          .doesNotExist("filters never create");
        assert.false(
          requests.called,
          "local intersections never search the server"
        );
      });

      test("local filter searches the whole list beyond the top-tag cap", async function (assert) {
        this.siteSettings.max_tags_in_filter_list = 1;
        const items = [
          { id: 1, name: "first" },
          { id: 2, name: "second" },
        ];
        await render(
          <template><DSelectTagFilter @items={{items}} /></template>
        );
        await click(".d-select__trigger");
        await fillIn(".d-select__panel input", "second");
        assert
          .dom("[role='option']")
          .hasText(
            "second",
            "matching local rows are found even beyond the initial cap"
          );
      });

      test("Backspace never clears a single filter", async function (assert) {
        const value = { id: 2, name: "other", slug: "other" };
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTagFilter @onChange={{onChange}} @value={{value}} />
          </template>
        );
        await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");
        assert.false(onChange.called, "not from the closed trigger");

        await click(".d-select__trigger");
        await triggerKeyEvent(".d-select__panel input", "keydown", "Backspace");
        assert.false(onChange.called, "not from the empty search field");
        assert
          .dom(".d-select__trigger")
          .includesText("other", "the filter keeps its tag");
      });

      test("the all-tags shortcut is how a single filter clears", async function (assert) {
        const value = { id: 2, name: "other", slug: "other" };
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTagFilter @onChange={{onChange}} @value={{value}} />
          </template>
        );
        await click(".d-select__trigger");
        await click(optionNamed(i18n("tagging.selector_remove_filter")));
        assert.strictEqual(onChange.lastCall?.args[0], ALL_TAGS_ID);
      });
    });
  }
);
