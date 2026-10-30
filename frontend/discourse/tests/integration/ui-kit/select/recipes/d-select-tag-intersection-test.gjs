import { hash } from "@ember/helper";
import { click, fillIn, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect as SelectDriver } from "discourse/tests/helpers/d-select-helper";
import DSelectTagIntersection from "discourse/ui-kit/select/recipes/tags/d-select-tag-intersection";
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

module(
  "Integration | ui-kit | select | recipes | DSelectTagIntersection",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      resetTagSourceCache();
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_search_results = 5;
      this.siteSettings.tags_sort_alphabetically = false;
    });

    module("values", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.routeTo = sinon.stub(DiscourseURL, "routeTo");
      });

      test("holds tags in order, by identity, with the intersection classes", async function (assert) {
        const requests = stubSearch();
        const onChange = sinon.spy();
        const main = { id: 2, name: "ui", slug: "ui" };
        const held = [main];

        await render(
          <template>
            <DSelectTagIntersection @onChange={{onChange}} @value={{held}} />
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

      test("suppressFooter: no footer region without a caller footer", async function (assert) {
        stubSearch();
        const onChange = () => {};
        await render(
          <template><DSelectTagIntersection @onChange={{onChange}} /></template>
        );
        await click(".d-select__trigger");

        assert.dom(optionNamed("bug")).exists("the panel is open");
        assert
          .dom(".d-select__footer")
          .doesNotExist("no empty footer region below the list");
      });

      test("local items, the site cap, and no creation", async function (assert) {
        this.siteSettings.max_tags_per_topic = 1;
        this.site.set("can_create_tag", true);
        const requests = sinon.spy();
        pretender.get("/tags/list.json", () => response({ list_tags: [] }));
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
            <DSelectTagIntersection @items={{items}} @value={{held}} />
          </template>
        );
        await click(".d-select__trigger");
        assert
          .dom(optionNamed("second"))
          .hasAttribute("aria-disabled", "true", "the site cap applies");
        await fillIn("[role='combobox']", "unknown");
        assert
          .dom("[role='option'].--create")
          .doesNotExist("an intersection never creates");
        assert.false(
          requests.called,
          "local intersections never search the server"
        );
      });

      test("signed out, held names are never looked up", async function (assert) {
        stubSearch();
        let lookups = 0;
        pretender.get("/tags/list.json", () => {
          lookups++;
          return response({ list_tags: [] });
        });
        this.owner.unregister("service:current-user");
        const held = [
          { id: 1, name: "alpha", slug: "alpha" },
          { name: "rock" },
        ];

        await render(
          <template><DSelectTagIntersection @value={{held}} /></template>
        );
        await click(".d-select__trigger");

        assert.strictEqual(lookups, 0, "the list endpoint needs a login");
        assert
          .dom(".d-select__chip[data-name='rock']")
          .exists("the held name still shows");
      });
    });

    module("names and texts", function () {
      test("it is named for what it filters, with tags as its empty text", async function (assert) {
        stubSearch();
        const held = [];

        await render(
          <template><DSelectTagIntersection @value={{held}} /></template>
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

      test("@ariaLabelledBy names it after a visible caption", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <span id="intersection-caption">Narrow by tags</span>
            <DSelectTagIntersection @ariaLabelledBy="intersection-caption" />
          </template>
        );

        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          "Narrow by tags"
        );
      });

      test("@texts names it and sets its empty text", async function (assert) {
        stubSearch();
        const held = [];

        await render(
          <template>
            <DSelectTagIntersection
              @texts={{hash ariaLabel="Narrow topics" placeholder="any tag"}}
              @value={{held}}
            />
          </template>
        );

        assert
          .dom("[role='combobox']")
          .hasAria("label", "Narrow topics")
          .hasAttribute("placeholder", "any tag");
      });

      test("it keeps its own prompt in a category with an unmet required group", async function (assert) {
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
            <div class="empty"><DSelectTagIntersection
                @categoryId={{7}}
                @value={{empty}}
              /></div>
            <div class="held"><DSelectTagIntersection
                @categoryId={{7}}
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

      test("a kind customization reaches its texts and the tag counts", async function (assert) {
        stubSearch();
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forKind("select-tag-intersection", (spec) =>
              spec.options(() => ({
                texts: {
                  placeholder: "more tags",
                  tagCount: ({ count }) => `${count} uses`,
                },
              }))
            )
          )
        );
        const held = [];

        await render(
          <template><DSelectTagIntersection @value={{held}} /></template>
        );
        assert
          .dom("[role='combobox']")
          .hasAttribute("placeholder", "more tags");

        await new SelectDriver(".d-select").open();
        assert.dom(".sr-only", optionNamed("bug")).hasText("4 uses");
      });
    });
  }
);
