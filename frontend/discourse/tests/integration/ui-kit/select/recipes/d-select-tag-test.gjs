import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  setupOnerror,
  triggerKeyEvent,
  typeIn,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { paste as pasteTags } from "discourse/tests/helpers/qunit-helpers";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
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

/** A controlled `DSelectTag`, as a call site would own it. */
class SelectTagHost extends Component {
  @tracked
  value = this.args.value ?? (this.args.multiple === false ? null : []);

  @action
  onChange(value) {
    this.args.onChange?.(value);
    this.value = value;
  }

  <template>
    <DSelectTag
      @allowCreate={{@allowCreate}}
      @emit={{@emit}}
      @exclude={{@exclude}}
      @excludeTagsWithSynonyms={{@excludeTagsWithSynonyms}}
      @ignoreRestrictions={{@ignoreRestrictions}}
      @legacyKind={{@legacyKind}}
      @maximum={{@maximum}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @suggestRecent={{@suggestRecent}}
      @value={{this.value}}
      @variant={{@variant}}
    />
  </template>
}

/** A controlled tag field, as a call site would own it. */
class TagFieldHost extends Component {
  @tracked tags = this.args.tags ?? [];

  @action
  onChange(tags) {
    this.args.onChange?.(tags);
    this.tags = tags;
  }

  <template>
    <DSelectTag
      @allowCreate={{@allowCreate}}
      @categoryId={{@categoryId}}
      @exclude={{@blockedTags}}
      @ignoreRestrictions={{@everyTag}}
      @maximum={{if @unlimitedTagCount false}}
      @onChange={{this.onChange}}
      @value={{this.tags}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | recipes | DSelectTag",
  function (hooks) {
    setupRenderingTest(hooks);

    module("arguments", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tag_search_results = 5;
        getOwner(this).lookup("service:site").set("can_create_tag", true);
      });

      test("its kind is select-tag and its legacy class defaults to tag-chooser", async function (assert) {
        stubSearch();
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-tag", (spec) =>
              spec.row((row) => row.classes.push("x-select-tag"))
            );
          })
        );

        await render(
          <template>
            <div class="default"><SelectTagHost /></div>
            <div class="mini"><SelectTagHost
                @legacyKind="mini-tag-chooser"
              /></div>
          </template>
        );

        assert.dom(".default .d-select").hasClass("tag-chooser");
        assert.dom(".mini .d-select").hasClass("mini-tag-chooser");
        await click(".default .d-select__trigger");
        assert.true(optionNamed("bug").classList.contains("x-select-tag"));
      });

      test("emits tag objects and accepts held names", async function (assert) {
        stubSearch();
        const onChange = sinon.spy();
        const held = ["ui"];

        await render(
          <template>
            <SelectTagHost @onChange={{onChange}} @value={{held}} />
          </template>
        );
        assert.dom(".d-select__chip").includesText("ui", "a held name renders");

        await click(".d-select__trigger");
        await click(optionNamed("bug"));

        const emitted = onChange.lastCall.args[0];
        assert.deepEqual(
          emitted.map((tag) => tag.name),
          ["ui", "bug"],
          "names in order"
        );
        assert.strictEqual(
          emitted[1].id,
          1,
          "the picked tag is its row object"
        );
      });

      test("@emit=names emits stored names, never a translation", async function (assert) {
        stubSearch([
          {
            id: 1,
            name: "戦略",
            text: "戦略",
            original_name: "strategy",
            count: 3,
          },
          { id: 2, name: "ui", text: "ui", count: 2 },
        ]);
        const onChange = sinon.spy();

        await render(
          <template>
            <SelectTagHost @emit="names" @onChange={{onChange}} />
          </template>
        );
        await click(".d-select__trigger");
        await click(optionNamed("戦略"));
        await click(optionNamed("ui"));

        assert.deepEqual(onChange.lastCall.args[0], ["strategy", "ui"]);
      });

      test("an unknown @emit value throws in development", async function (assert) {
        stubSearch();
        let error;
        setupOnerror((e) => (error = e));

        await render(<template><SelectTagHost @emit="name" /></template>);

        assert.true(
          String(error?.message).includes("@emit"),
          "the assertion names the argument"
        );
        setupOnerror();
      });

      test("creation needs both @allowCreate and the site permission", async function (assert) {
        stubSearch();
        const site = getOwner(this).lookup("service:site");

        await render(
          <template>
            <div class="allowed"><SelectTagHost @allowCreate={{true}} /></div>
            <div class="default"><SelectTagHost /></div>
          </template>
        );

        await click(".allowed .d-select__trigger");
        await fillIn(".allowed [role='combobox']", "newtag");
        assert
          .dom("[role='option'].--create")
          .exists("allowed by the call site and the site");
        await triggerKeyEvent(
          ".allowed [role='combobox']",
          "keydown",
          "Escape"
        );

        await click(".default .d-select__trigger");
        await fillIn(".default [role='combobox']", "newtag");
        assert
          .dom("[role='option'].--create")
          .doesNotExist("the site permission alone is not enough");
        await triggerKeyEvent(
          ".default [role='combobox']",
          "keydown",
          "Escape"
        );

        site.set("can_create_tag", false);
        await click(".allowed .d-select__trigger");
        await fillIn(".allowed [role='combobox']", "othertag");
        assert
          .dom("[role='option'].--create")
          .doesNotExist("the call site alone is not enough");
      });

      test("the site tag limit caps by default and false lifts it", async function (assert) {
        stubSearch();
        this.siteSettings.max_tags_per_topic = 1;
        const held = [{ id: 2, name: "ui" }];

        await render(
          <template>
            <div class="capped"><SelectTagHost @value={{held}} /></div>
            <div class="open"><SelectTagHost
                @maximum={{false}}
                @value={{held}}
              /></div>
          </template>
        );

        await click(".capped .d-select__trigger");
        assert
          .dom(optionNamed("bug"))
          .hasAttribute("aria-disabled", "true", "at the site limit");
        await triggerKeyEvent(".capped [role='combobox']", "keydown", "Escape");

        await click(".open .d-select__trigger");
        assert
          .dom(optionNamed("bug"))
          .doesNotHaveAttribute("aria-disabled", "no cap with false");
      });

      test("a site limit of 0 blocks additions but keeps removal; an explicit 0 does not", async function (assert) {
        stubSearch();
        this.siteSettings.max_tags_per_topic = 0;
        const onChange = sinon.spy();
        const held = [{ id: 2, name: "ui" }];

        await render(
          <template>
            <div class="site"><SelectTagHost
                @allowCreate={{true}}
                @onChange={{onChange}}
                @value={{held}}
              /></div>
            <div class="explicit"><SelectTagHost
                @maximum={{0}}
                @value={{held}}
              /></div>
          </template>
        );

        await click(".site .d-select__trigger");
        assert
          .dom(optionNamed("bug"))
          .hasAttribute("aria-disabled", "true", "no additions");
        await fillIn(".site [role='combobox']", "newtag");
        assert.dom("[role='option'].--create").doesNotExist("no creation");
        await triggerKeyEvent(".site [role='combobox']", "keydown", "Escape");

        await click(".site .d-select__chip-remove");
        assert.deepEqual(
          onChange.lastCall.args[0],
          [],
          "the held tag is removed"
        );

        await click(".explicit .d-select__trigger");
        assert
          .dom(optionNamed("bug"))
          .doesNotHaveAttribute("aria-disabled", "an explicit 0 means no cap");
      });

      test("single mode holds one tag, matched by name, and does not send it as selected", async function (assert) {
        const requests = stubSearch();
        const onChange = sinon.spy();

        await render(
          <template>
            <SelectTagHost
              @exclude={{array "perf"}}
              @multiple={{false}}
              @onChange={{onChange}}
              @value="ui"
            />
          </template>
        );
        await click(".d-select__trigger");

        assert
          .dom(optionNamed("ui"))
          .hasAttribute("aria-selected", "true", "the name matches the row");
        assert.strictEqual(
          optionNamed("perf"),
          undefined,
          "an excluded tag is not offered"
        );

        await click(optionNamed("ui"));
        assert.false(
          onChange.called,
          "re-picking the held tag is not a change"
        );

        await click(".d-select__trigger");
        await click(optionNamed("bug"));
        assert.strictEqual(onChange.lastCall.args[0].id, 1, "one tag object");

        const selected = [].concat(requests.at(-1)?.selected_tag_ids ?? []);
        assert.false(selected.includes("2"), "the held tag is not sent");
      });

      test("@exclude still sends the excluded ids", async function (assert) {
        const requests = stubSearch();
        const excluded = [{ id: 3, name: "perf" }];

        await render(
          <template><SelectTagHost @exclude={{excluded}} /></template>
        );
        await click(".d-select__trigger");

        assert.strictEqual(optionNamed("perf"), undefined, "not offered");
        assert.true(
          [].concat(requests.at(-1).selected_tag_ids ?? []).includes("3"),
          "sent as selected so the server fills the page with usable tags"
        );
      });

      test("search options map onto the request", async function (assert) {
        this.siteSettings.prioritize_recently_used_tags = true;
        const requests = stubSearch();

        await render(
          <template>
            <div class="restricted"><SelectTagHost /></div>
            <div class="all"><SelectTagHost
                @excludeTagsWithSynonyms={{true}}
                @ignoreRestrictions={{true}}
                @suggestRecent={{true}}
              /></div>
          </template>
        );

        await click(".restricted .d-select__trigger");
        assert.strictEqual(requests.at(-1).filterForInput, "true");
        await triggerKeyEvent(
          ".restricted [role='combobox']",
          "keydown",
          "Escape"
        );

        await click(".all .d-select__trigger");
        const last = requests.at(-1);
        assert.strictEqual(last.filterForInput, undefined, "all tags");
        assert.strictEqual(last.excludeHasSynonyms, "true");
        assert.strictEqual(last.prioritizeRecentTags, "true");
      });

      test("@variant=button renders a button trigger", async function (assert) {
        stubSearch();

        await render(
          <template>
            <SelectTagHost @multiple={{false}} @variant="button" />
          </template>
        );

        assert.dom(".d-select__trigger").doesNotHaveClass("--typeahead");
        await click(".d-select__trigger");
        assert
          .dom(".d-select__panel input")
          .exists("the search is in the panel");
      });
    });

    module("search, rows and creation", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tag_search_results = 5;
        this.site.set("can_create_tag", true);
        stubSearch();
      });

      test("search sends the category, held and blocked ids", async function (assert) {
        const requests = stubSearch();

        await render(
          <template>
            <TagFieldHost
              @blockedTags={{array (hash id=9 name="blocked")}}
              @categoryId={{7}}
              @tags={{array (hash id=2 name="ui")}}
            />
          </template>
        );
        await click(".d-select__trigger");

        const params = requests.at(-1);
        const selected =
          params["selected_tag_ids[]"] ?? params.selected_tag_ids;
        assert.strictEqual(params.categoryId, "7");
        assert.deepEqual([...selected].sort(), ["2", "9"]);
        assert.strictEqual(
          params.filterForInput,
          "true",
          "input rules apply by default"
        );
      });

      test("rows are tags without links, counts hidden from the name", async function (assert) {
        stubSearch();

        await render(<template><TagFieldHost /></template>);
        await click(".d-select__trigger");

        const bug = optionNamed("bug");
        assert
          .dom(bug.querySelector(".discourse-tag"))
          .exists("renders the tag");
        assert
          .dom(bug.querySelector("a[href]"))
          .doesNotExist("no link inside an option");
        const hidden = [...bug.querySelectorAll("[aria-hidden='true']")].map(
          (el) => el.textContent.trim()
        );
        assert.true(
          hidden.some((text) => text.includes("4")),
          "the count is visible but hidden from assistive tech"
        );
      });

      test("picking a row keeps held tags by identity and adds the row", async function (assert) {
        stubSearch();
        const onChange = sinon.spy();
        const held = { id: 2, name: "ui" };

        await render(
          <template>
            <TagFieldHost @onChange={{onChange}} @tags={{array held}} />
          </template>
        );
        await click(".d-select__trigger");
        await click(optionNamed("bug"));

        const [tags] = onChange.lastCall.args;
        assert.strictEqual(tags[0], held, "the held object passes through");
        assert.deepEqual(tags[1], ROWS[0], "the picked row is the server row");
      });

      test("a permitted create adds a new tag", async function (assert) {
        stubSearch();
        const onChange = sinon.spy();

        await render(
          <template>
            <TagFieldHost @allowCreate={{true}} @onChange={{onChange}} />
          </template>
        );
        await click(".d-select__trigger");
        await fillIn("[role='combobox']", "newtag");

        assert.dom("[role='option'].--create").hasText("Create “newtag”");
        await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

        assert.deepEqual(onChange.lastCall.args[0], [
          { id: "newtag", name: "newtag", isNew: true },
        ]);
      });

      test("pasting pipe-separated names adds each tag", async function (assert) {
        stubSearch();
        const onChange = sinon.spy();

        await render(
          <template>
            <TagFieldHost @allowCreate={{true}} @onChange={{onChange}} />
          </template>
        );
        await click(".d-select__trigger");

        const clipboardData = new DataTransfer();
        clipboardData.setData("text/plain", "alpha|beta|gamma");
        const input = find("[role='combobox']");
        input.dispatchEvent(
          new ClipboardEvent("paste", {
            bubbles: true,
            cancelable: true,
            clipboardData,
          })
        );
        await settled();

        assert.deepEqual(
          onChange.lastCall?.args[0].map((tag) => tag.name),
          ["alpha", "beta", "gamma"]
        );
        assert
          .dom(input)
          .hasValue("", "the pasted text is not left as a query");
      });

      test("a forbidden term offers no create row", async function (assert) {
        stubSearch([], { forbidden: "evil", forbidden_message: "No" });

        await render(
          <template><TagFieldHost @allowCreate={{true}} /></template>
        );
        await click(".d-select__trigger");
        await fillIn("[role='combobox']", "evil");

        assert.dom("[role='option'].--create").doesNotExist();
      });

      test("a disabled row shows why", async function (assert) {
        stubSearch([
          {
            id: 5,
            name: "child",
            text: "child",
            count: 0,
            disabled: true,
            title: "Requires parent",
          },
        ]);

        await render(<template><TagFieldHost /></template>);
        await click(".d-select__trigger");

        assert.dom(optionNamed("child")).hasAttribute("aria-disabled", "true");
        assert.dom(optionNamed("child")).includesText("Requires parent");
      });

      test("Enter creates a typed tag once the list has changed", async function (assert) {
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @legacyKind="mini-tag-chooser"
              @onChange={{onChange}}
            />
          </template>
        );
        await click(".d-select__trigger");
        assert.notStrictEqual(optionNamed("bug"), undefined, "the first list");

        await typeIn("[role='combobox']", "fresh");
        const createRow = find("[role='option'].--create");
        assert.true(Boolean(createRow?.id), "the create row has an id");
        assert
          .dom("[role='combobox']")
          .hasAttribute(
            "aria-activedescendant",
            createRow?.id ?? "",
            "the create row is the active option"
          );

        await triggerKeyEvent("[role='combobox']", "keydown", "Enter");

        assert.true(onChange.called, "Enter created the tag");
        assert.true(
          onChange.lastCall.args[0].some(
            (tag) => tag.name === "fresh" && tag.isNew
          )
        );
      });

      test("a minimum shows as persistent guidance", async function (assert) {
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @legacyKind="mini-tag-chooser"
              @minimum={{2}}
            />
          </template>
        );

        const input = find("[role='combobox']");
        const described = (input.getAttribute("aria-describedby") ?? "")
          .split(/\s+/)
          .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
          .join(" ");
        assert.true(
          /2/.test(described),
          `the requirement is described: ${described}`
        );
      });
    });

    module("name resolution, guidance and blocks", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        resetTagSourceCache();
        this.site.set("can_create_tag", true);
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tag_search_results = 5;
        this.siteSettings.max_tag_length = 20;
        this.siteSettings.force_lowercase_tags = true;
      });

      nestedHooks.afterEach(function () {
        resetTagSourceCache();
      });

      test("resolves name-only held and blocked tags before opening and after value changes", async function (assert) {
        const lookups = [];
        const searches = [];
        pretender.get("/tags/list.json", (request) => {
          lookups.push(request.queryParams.only_tags);
          return response({
            list_tags: [
              { id: lookups.length === 1 ? 12 : 13, name: "localized" },
            ],
          });
        });
        pretender.get("/tags/filter/search", (request) => {
          searches.push(request.queryParams);
          return response({ results: [] });
        });
        const tags = tracked([{ name: "held" }]);
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag
              @exclude={{array "blocked" (hash id=9 name="numeric")}}
              @onChange={{onChange}}
              @value={{tags.value}}
            />
          </template>
        );
        assert.deepEqual(
          lookups,
          ["blocked,held"],
          "names resolve while closed"
        );
        assert.strictEqual(
          searches.length,
          0,
          "resolution does not open the search"
        );
        const select = new DSelect();
        await select.open();
        assert.deepEqual(
          (
            searches.at(-1)["selected_tag_ids[]"] ??
            searches.at(-1).selected_tag_ids
          ).sort(),
          ["12", "9"],
          "only numeric resolved ids reach search"
        );
        await select.close();
        tags.value = ["replacement"];
        await settled();
        assert.deepEqual(
          lookups,
          ["blocked,held", "blocked,replacement"],
          "replacement resolves without opening"
        );
        await select.open();
        assert.deepEqual(
          (
            searches.at(-1)["selected_tag_ids[]"] ??
            searches.at(-1).selected_tag_ids
          ).sort(),
          ["13", "9"],
          "old resolved ids do not survive a value replacement"
        );
      });

      test("pending name resolution does not block searching and reloads with resolved ids", async function (assert) {
        let lookup;
        const searches = [];
        pretender.get(
          "/tags/list.json",
          (request) => {
            lookup = request;
            return response({ list_tags: [{ id: 12, name: "localized" }] });
          },
          true
        );
        pretender.get("/tags/filter/search", (request) => {
          searches.push(request.queryParams);
          return response({ results: [{ id: 1, name: "available" }] });
        });
        const onChange = () => {};
        const rendering = render(
          <template>
            <DSelectTag
              @exclude={{array (hash id=9 name="blocked")}}
              @onChange={{onChange}}
              @value={{array "held"}}
            />
          </template>
        );
        let typing;
        try {
          await waitUntil(() => lookup);
          find(".d-select__trigger").click();
          await waitUntil(() => searches.length);
          typing = fillIn("[role='combobox']", "available");
          await waitUntil(() => searches.some(({ q }) => q === "available"));
          await waitUntil(() => find("[role='option']"));
          assert
            .dom("[role='option']")
            .hasText(
              "available",
              "search results render while the lookup is still pending"
            );
          const selectedIds =
            searches.at(-1)["selected_tag_ids[]"] ??
            searches.at(-1).selected_tag_ids;
          assert.deepEqual(
            selectedIds,
            ["9"],
            "known ids are sent without unresolved names"
          );
        } finally {
          pretender.resolve(lookup);
          await rendering;
          await typing;
          await settled();
        }
        assert.deepEqual(
          (
            searches.at(-1)["selected_tag_ids[]"] ??
            searches.at(-1).selected_tag_ids
          ).sort(),
          ["12", "9"],
          "settling the lookup reloads the open search with resolved ids"
        );
      });

      test("failed name resolution leaves unresolved names out and searching available", async function (assert) {
        const searches = [];
        pretender.get("/tags/list.json", () =>
          response(500, { errors: ["Lookup failed"] })
        );
        pretender.get("/tags/filter/search", (request) => {
          searches.push(request.queryParams);
          return response({ results: [{ id: 1, name: "available" }] });
        });
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag
              @exclude={{array (hash id=9 name="blocked")}}
              @onChange={{onChange}}
              @value={{array "held"}}
            />
          </template>
        );
        await new DSelect().search("available");
        assert
          .dom("[role='option']")
          .hasText(
            "available",
            "a failed lookup does not become a search error"
          );
        const selectedIds =
          searches.at(-1)["selected_tag_ids[]"] ??
          searches.at(-1).selected_tag_ids;
        assert.deepEqual(
          selectedIds,
          ["9"],
          "only known ids reach search after failure"
        );
      });

      test("creation checks cleaned stored and held names case-insensitively", async function (assert) {
        pretender.get("/tags/list.json", () => response({ list_tags: [] }));
        pretender.get("/tags/filter/search", () =>
          response({
            results: [
              {
                id: 5,
                name: "Alias",
                original_name: "existing",
                text: "Alias",
              },
            ],
          })
        );
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @onChange={{onChange}}
              @value={{array "Held"}}
            />
          </template>
        );
        const select = new DSelect();
        for (const term of ["EXISTING!", "HELD!", "..."]) {
          await select.search(term);
          assert
            .dom("[role='option'].--create")
            .doesNotExist(`rejects ${term} after cleaning`);
        }
        await select.search("fresh!");
        assert
          .dom("[role='option'].--create")
          .hasText(
            "Create “fresh”",
            "a distinct cleaned name remains creatable"
          );
      });

      test("blocked names ignore case and disabled reasons remain visible", async function (assert) {
        pretender.get("/tags/list.json", () => response({ list_tags: [] }));
        pretender.get("/tags/filter/search", () =>
          response({
            results: [
              { id: 1, name: "BLOCKED" },
              {
                id: 2,
                name: "child",
                disabled: true,
                title: "Requires parent",
                count: 1,
              },
            ],
          })
        );
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag @exclude={{array "blocked"}} @onChange={{onChange}} />
          </template>
        );
        await new DSelect().open();
        assert
          .dom("[role='option']")
          .exists({ count: 1 }, "blocked names are excluded");
        assert
          .dom("[role='option']")
          .includesText("Requires parent", "the source reason is visible");
        assert
          .dom("[role='option'] .sr-only")
          .hasText(
            i18n("tagging.tag_count_hidden", { count: 1 }),
            "count has an accessible singular phrase"
          );
        assert
          .dom(".discourse-tag .discourse-tag-count")
          .doesNotExist("count is outside the tag name");
      });

      test("required-group guidance persists through describedBy and follows category context", async function (assert) {
        pretender.get("/tags/filter/search", (request) =>
          response({
            results: [],
            ...(request.queryParams.categoryId === "7"
              ? { required_tag_group: { name: "Required", min_count: 2 } }
              : {}),
          })
        );
        const category = tracked(7);
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag
              @categoryId={{category.value}}
              @minimum={{1}}
              @onChange={{onChange}}
            />
          </template>
        );
        const select = new DSelect();
        await select.open();
        const id = find("[role='combobox']")
          .getAttribute("aria-describedby")
          .split(" ")
          .find((part) => part.endsWith("-tag-guidance"));
        assert.dom(`#${id}`).hasText(
          i18n("tagging.choose_for_topic_required_group", {
            count: 2,
            name: "Required",
          }),
          "required group is persistent help"
        );
        category.value = 8;
        await settled();
        assert
          .dom(`#${id}`)
          .hasText(
            i18n("tagging.choose_for_topic_required", { count: 1 }),
            "old category guidance does not survive"
          );
      });

      test("forwards item, selection and footer blocks", async function (assert) {
        pretender.get("/tags/filter/search", () =>
          response({ results: [{ id: 1, name: "row" }] })
        );
        const onChange = () => {};
        await render(
          <template>
            <DSelectTag
              @onChange={{onChange}}
              @value={{array (hash id=2 name="held")}}
            >
              <:item as |item|>
                <span class="custom-row">
                  {{~item.name~}}
                </span>
              </:item>
              <:selection as |item|>
                <span class="custom-held">
                  {{~item.name~}}
                </span>
              </:selection>
              <:footer as |state|>
                <span class="custom-footer">
                  {{~state.loadedCount~}}
                </span>
              </:footer>
            </DSelectTag>
          </template>
        );
        assert
          .dom(".custom-held")
          .hasText("held", "selection block is forwarded");
        await new DSelect().open();
        assert.dom(".custom-row").hasText("row", "item block is forwarded");
        assert.dom(".custom-footer").hasText("1", "footer block is forwarded");
      });
    });

    module("paste", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.site.set("can_create_tag", true);
        this.siteSettings.max_tags_per_topic = 5;
        this.siteSettings.max_tag_length = 20;
        this.siteSettings.force_lowercase_tags = true;
      });

      test("pipe paste preserves loaded tags and respects creation permission", async function (assert) {
        const rows = [
          { id: 12, name: "Alpha", count: 4 },
          { id: 13, name: "Beta", count: 2 },
        ];
        const load = async () => ({ items: rows, total: rows.length });
        const tags = tracked([]);
        const onChange = sinon.spy((next) => (tags.value = next));
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @load={{load}}
              @onChange={{onChange}}
              @value={{tags.value}}
            />
          </template>
        );
        await new DSelect().open();

        const paste = async (text) => {
          const clipboardData = new DataTransfer();
          clipboardData.setData("text/plain", text);
          const event = new ClipboardEvent("paste", {
            bubbles: true,
            cancelable: true,
            clipboardData,
          });
          find("[role='combobox']").dispatchEvent(event);
          await settled();
          return event;
        };
        await paste(" ALPHA | | fresh-tag | BETA | ");
        assert.deepEqual(
          tags.value,
          [
            rows[0],
            { id: "fresh-tag", name: "fresh-tag", isNew: true },
            rows[1],
          ],
          "trimmed names reuse loaded rows case-insensitively and create only unknown tags"
        );

        const single = await paste(" just-one | ");
        assert.false(
          single.defaultPrevented,
          "a single token keeps native paste"
        );
        assert.true(
          onChange.calledOnce,
          "native paste does not change selection"
        );

        tags.value = [];
        this.site.set("can_create_tag", false);
        await settled();
        await paste("ALPHA|another-new-tag|BETA");
        assert.deepEqual(
          tags.value,
          rows,
          "without creation permission only the existing rows are selected"
        );
      });
    });

    module("stored names, local sources and site caps", function (nestedHooks) {
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

      test("validates emit when its argument changes", async function (assert) {
        const emit = tracked(undefined);
        let error;
        setupOnerror((e) => (error = e));
        try {
          await render(
            <template><DSelectTag @emit={{emit.value}} /></template>
          );
          emit.value = "name";
          await settled();
          assert.true(
            String(error?.message).includes("@emit"),
            "the changed argument is validated"
          );
        } finally {
          setupOnerror();
        }
      });

      test("single held stored name matches a translated row", async function (assert) {
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @multiple={{false}}
              @onChange={{onChange}}
              @value="STRATEGY"
            />
          </template>
        );
        await click(".d-select__trigger");
        const row = findAll("[role='option']").find((el) =>
          el.textContent.includes("戦略")
        );
        assert
          .dom(row)
          .hasAttribute(
            "aria-selected",
            "true",
            "stored names match regardless of case"
          );
        await click(row);
        assert.false(onChange.called, "re-picking is not a change");
      });

      test("excludes translated stored names in single mode and sends excluded ids", async function (assert) {
        const requests = [];
        pretender.get("/tags/filter/search", (request) => {
          requests.push(request.queryParams);
          return response({
            results: [
              { id: 3, name: "除外", original_name: "excluded" },
              { id: 2, name: "other" },
            ],
          });
        });
        const excluded = ["EXCLUDED"];
        await render(
          <template>
            <DSelectTag
              @exclude={{excluded}}
              @multiple={{false}}
              @value="held"
            />
          </template>
        );
        await click(".d-select__trigger");
        assert
          .dom("[role='option']")
          .exists({ count: 1 }, "the translated excluded row is absent");
        assert.deepEqual(
          [].concat(
            requests.at(-1)["selected_tag_ids[]"] ??
              requests.at(-1).selected_tag_ids
          ),
          ["3"],
          "only excluded ids reach the server"
        );
      });

      test("duplicate creation and paste use stored names", async function (assert) {
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag @allowCreate={{true}} @onChange={{onChange}} />
          </template>
        );
        await click(".d-select__trigger");
        await fillIn("[role='combobox']", "strategy");
        assert
          .dom("[role='option'].--create")
          .doesNotExist(
            "a translated existing row prevents duplicate creation"
          );
        await fillIn("[role='combobox']", "");
        await pasteTags("[role='combobox']", "STRATEGY|newtag");
        assert.deepEqual(
          onChange.lastCall.args[0].map((tag) => [tag.id, tag.name]),
          [
            [1, "戦略"],
            ["newtag", "newtag"],
          ],
          "paste resolves stored names and creates only unknown names"
        );
      });

      test("site zero blocks paste creation while keeping removal", async function (assert) {
        this.siteSettings.max_tags_per_topic = 0;
        const value = tracked([{ id: 2, name: "other" }]);
        const onChange = (next) => {
          value.value = next;
        };
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @onChange={{onChange}}
              @value={{value.value}}
            />
          </template>
        );
        await click(".d-select__trigger");
        await pasteTags("[role='combobox']", "new-one|new-two");
        assert.deepEqual(
          value.value.map((tag) => tag.name),
          ["other"],
          "paste cannot create at zero"
        );
        await triggerKeyEvent("[role='combobox']", "keydown", "Escape");
        await click(".d-select__chip-remove");
        assert.deepEqual(value.value, [], "chips remain removable");
      });

      test("local tag sources match held names and exclude translated rows without requests", async function (assert) {
        const requests = sinon.spy();
        pretender.get("/tags/filter/search", () => {
          requests();
          return response({ results: [] });
        });
        const items = [
          { id: 1, name: "戦略", original_name: "strategy" },
          { id: 2, name: "other" },
          { id: 3, name: "除外", original_name: "excluded" },
        ];
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @exclude={{array "excluded"}}
              @items={{items}}
              @multiple={{false}}
              @onChange={{onChange}}
              @value="STRATEGY"
            />
          </template>
        );
        await click(".d-select__trigger");
        const translated = findAll("[role='option']").find((row) =>
          row.textContent.includes("戦略")
        );
        assert
          .dom(translated)
          .hasAttribute(
            "aria-selected",
            "true",
            "a local stored name matches too"
          );
        assert
          .dom("[role='option']")
          .exists({ count: 2 }, "excluded translated rows are absent");
        await click(translated);
        assert.false(
          onChange.called,
          "re-picking a local held name is unchanged"
        );
        assert.false(
          requests.called,
          "a local source never searches the server"
        );
      });

      test("a zero site cap disables only unselected rows, including held names", async function (assert) {
        this.siteSettings.max_tags_per_topic = 0;
        const value = tracked(["STRATEGY"]);
        const onChange = (next) => {
          value.value = next;
        };
        await render(
          <template>
            <DSelectTag @onChange={{onChange}} @value={{value.value}} />
          </template>
        );
        await click(".d-select__trigger");
        const translated = findAll("[role='option']").find((row) =>
          row.textContent.includes("戦略")
        );
        assert
          .dom(translated)
          .hasAttribute(
            "aria-selected",
            "true",
            "the name matches the selected row"
          );
        assert
          .dom(translated)
          .doesNotHaveAttribute(
            "aria-disabled",
            "a selected row remains enabled"
          );
        await click(translated);
        assert.deepEqual(value.value, [], "selected rows can be removed");
      });

      test("custom loaders still apply exclusion and the zero site cap", async function (assert) {
        this.siteSettings.max_tags_per_topic = 0;
        const load = sinon.spy(async () => ({
          items: [
            { id: 1, name: "戦略", original_name: "strategy" },
            { id: 2, name: "other" },
            { id: 3, name: "除外", original_name: "excluded" },
          ],
          hasMore: false,
        }));
        const onChange = sinon.spy();
        const held = ["STRATEGY"];
        await render(
          <template>
            <DSelectTag
              @exclude={{array "excluded"}}
              @load={{load}}
              @onChange={{onChange}}
              @value={{held}}
            />
          </template>
        );
        await click(".d-select__trigger");
        assert.true(load.called, "the override is used");
        assert
          .dom("[role='option']")
          .exists({ count: 2 }, "exclusion applies to override rows");
        const other = findAll("[role='option']").find((row) =>
          row.textContent.includes("other")
        );
        assert
          .dom(other)
          .hasAttribute(
            "aria-disabled",
            "true",
            "the zero site cap applies to override rows"
          );
        await click(other);
        assert.false(
          onChange.called,
          "an override cannot bypass the zero site cap"
        );
      });

      test("local creation needs both permissions and does not recreate excluded tags", async function (assert) {
        const items = [];
        const excluded = ["excluded"];
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @exclude={{excluded}}
              @items={{items}}
              @onChange={{onChange}}
            />
          </template>
        );
        await click(".d-select__trigger");
        await fillIn("[role='combobox']", "excluded");
        assert
          .dom("[role='option'].--create")
          .doesNotExist("excluded names cannot be recreated");
        await fillIn("[role='combobox']", "newtag");
        assert
          .dom("[role='option'].--create")
          .exists("local sources can create with both permissions");
        await click("[role='option'].--create");
        assert.deepEqual(
          onChange.lastCall.args[0],
          [{ id: "newtag", name: "newtag", isNew: true }],
          "created rows have the public tag shape"
        );
      });

      test("single creation replaces a held tag at the site cap", async function (assert) {
        this.siteSettings.max_tags_per_topic = 1;
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @allowCreate={{true}}
              @multiple={{false}}
              @onChange={{onChange}}
              @value="other"
            />
          </template>
        );
        await click(".d-select__trigger");
        await fillIn("[role='combobox']", "newtag");
        assert
          .dom("[role='option'].--create")
          .exists("a single choice can replace its held tag");
        await click("[role='option'].--create");
        assert.deepEqual(
          onChange.lastCall.args[0],
          { id: "newtag", name: "newtag", isNew: true },
          "one new tag object is emitted"
        );
      });

      test("functional local sources receive options and match stored names", async function (assert) {
        const requests = sinon.spy();
        pretender.get("/tags/filter/search", () => {
          requests();
          return response({ results: [] });
        });
        const rows = [
          { id: 1, name: "戦略", original_name: "strategy" },
          { id: 2, name: "other" },
        ];
        const items = sinon.spy(() => rows);
        const onChange = sinon.spy();
        await render(
          <template>
            <DSelectTag
              @emit="names"
              @items={{items}}
              @label="Functional tags"
              @multiple={{false}}
              @onChange={{onChange}}
              @value="STRATEGY"
            />
          </template>
        );
        await click(".d-select__trigger");
        const translated = findAll("[role='option']").find((row) =>
          row.textContent.includes("戦略")
        );
        assert
          .dom(translated)
          .hasAttribute(
            "aria-selected",
            "true",
            "functional sources match stored names"
          );
        assert.strictEqual(
          items.lastCall.args[0].label,
          "Functional tags",
          "resolved presentation options reach the source"
        );
        await fillIn("[role='combobox']", "other");
        assert
          .dom("[role='option']")
          .exists({ count: 1 }, "functional rows are filtered locally");
        await click("[role='option']");
        assert.strictEqual(
          onChange.lastCall.args[0],
          "other",
          "names mode emits a single name"
        );
        assert.false(
          requests.called,
          "functional local sources never search the server"
        );
      });
    });
  }
);
