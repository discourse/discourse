import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  settled,
  setupOnerror,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { paste as pasteTags } from "discourse/tests/helpers/qunit-helpers";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";
import { i18n } from "discourse-i18n";

module(
  "Integration | ui-kit | select | recipes | DTagChooser details",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      resetTagSourceCache();
      this.site.set("can_create_tag", true);
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_search_results = 5;
      this.siteSettings.max_tag_length = 20;
      this.siteSettings.force_lowercase_tags = true;
    });

    hooks.afterEach(function () {
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
          <DTagChooser
            @blockedTags={{array "blocked" (hash id=9 name="numeric")}}
            @onChange={{onChange}}
            @tags={{tags.value}}
          />
        </template>
      );
      assert.deepEqual(lookups, ["blocked,held"], "names resolve while closed");
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
          <DTagChooser
            @blockedTags={{array (hash id=9 name="blocked")}}
            @onChange={{onChange}}
            @tags={{array "held"}}
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
          <DTagChooser
            @blockedTags={{array (hash id=9 name="blocked")}}
            @onChange={{onChange}}
            @tags={{array "held"}}
          />
        </template>
      );
      await new DSelect().search("available");
      assert
        .dom("[role='option']")
        .hasText("available", "a failed lookup does not become a search error");
      const selectedIds =
        searches.at(-1)["selected_tag_ids[]"] ??
        searches.at(-1).selected_tag_ids;
      assert.deepEqual(
        selectedIds,
        ["9"],
        "only known ids reach search after failure"
      );
    });

    test("zero cap blocks picks and creation but permits chip removal", async function (assert) {
      pretender.get("/tags/filter/search", () =>
        response({ results: [{ id: 1, name: "available" }] })
      );
      const onChange = sinon.spy();
      await render(
        <template>
          <DTagChooser
            @allowCreate={{true}}
            @maximum={{0}}
            @onChange={{onChange}}
            @tags={{array (hash id=2 name="held")}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();
      assert
        .dom("[role='option']")
        .hasAttribute(
          "aria-disabled",
          "true",
          "zero refuses ordinary additions"
        );
      await click("[role='option']");
      assert.false(onChange.called, "a disabled pick does not emit");
      await select.search("new");
      assert
        .dom("[role='option'].--create")
        .doesNotExist("zero also refuses creation");
      await select.remove(2);
      assert.deepEqual(
        onChange.lastCall.args[0],
        [],
        "removal remains available"
      );
    });

    test("creation checks cleaned loaded names, text and held names case-insensitively", async function (assert) {
      pretender.get("/tags/list.json", () => response({ list_tags: [] }));
      pretender.get("/tags/filter/search", () =>
        response({ results: [{ id: 5, name: "existing", text: "Alias" }] })
      );
      const onChange = () => {};
      await render(
        <template>
          <DTagChooser
            @allowCreate={{true}}
            @onChange={{onChange}}
            @tags={{array "Held"}}
          />
        </template>
      );
      const select = new DSelect();
      for (const term of ["EXISTING!", "ALIAS!", "HELD!", "..."]) {
        await select.search(term);
        assert
          .dom("[role='option'].--create")
          .doesNotExist(`rejects ${term} after cleaning`);
      }
      await select.search("fresh!");
      assert
        .dom("[role='option'].--create")
        .hasText("Create “fresh”", "a distinct cleaned name remains creatable");
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
          <DTagChooser
            @blockedTags={{array "blocked"}}
            @onChange={{onChange}}
          />
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
          <DTagChooser
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
          <DTagChooser
            @onChange={{onChange}}
            @tags={{array (hash id=2 name="held")}}
          >
            <:item as |item|><span
                class="custom-row"
              >{{item.name}}</span></:item>
            <:selection as |item|><span
                class="custom-held"
              >{{item.name}}</span></:selection>
            <:footer as |state|><span
                class="custom-footer"
              >{{state.loadedCount}}</span></:footer>
          </DTagChooser>
        </template>
      );
      assert
        .dom(".custom-held")
        .hasText("held", "selection block is forwarded");
      await new DSelect().open();
      assert.dom(".custom-row").hasText("row", "item block is forwarded");
      assert.dom(".custom-footer").hasText("1", "footer block is forwarded");
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | DTagChooser paste",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.site.set("can_create_tag", true);
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_length = 20;
      this.siteSettings.force_lowercase_tags = true;
    });

    test("fix oracle: pipe paste preserves loaded tags and respects creation permission", async function (assert) {
      const rows = [
        { id: 12, name: "Alpha", count: 4 },
        { id: 13, name: "Beta", count: 2 },
      ];
      const load = async () => ({ items: rows, total: rows.length });
      const tags = tracked([]);
      const onChange = sinon.spy((next) => (tags.value = next));
      await render(
        <template>
          <DTagChooser
            @allowCreate={{true}}
            @load={{load}}
            @onChange={{onChange}}
            @tags={{tags.value}}
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
        [rows[0], { id: "fresh-tag", name: "fresh-tag", isNew: true }, rows[1]],
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
  }
);

module(
  "Integration | ui-kit | select | recipes | Unit 4 supplements",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
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

    test("unit 4 supplement: validates emit when its argument changes", async function (assert) {
      const emit = tracked(undefined);
      let error;
      setupOnerror((e) => (error = e));
      try {
        await render(<template><DSelectTag @emit={{emit.value}} /></template>);
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

    test("unit 4 supplement: single held stored name matches a translated row", async function (assert) {
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

    test("unit 4 supplement: excludes translated stored names in single mode and sends excluded ids", async function (assert) {
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
          <DSelectTag @exclude={{excluded}} @multiple={{false}} @value="held" />
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

    test("unit 4 supplement: duplicate creation and paste use stored names", async function (assert) {
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
        .doesNotExist("a translated existing row prevents duplicate creation");
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

    test("unit 4 supplement: site zero blocks paste creation while keeping removal", async function (assert) {
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
    test("unit 4 supplement: local tag sources match held names and exclude translated rows without requests", async function (assert) {
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
      assert.false(requests.called, "a local source never searches the server");
    });

    test("unit 4 supplement: a zero site cap disables only unselected rows, including held names", async function (assert) {
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

    test("unit 4 supplement: multiple filters use local items, enforce the site cap and never create", async function (assert) {
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
      const second = findAll("[role='option']").find((row) =>
        row.textContent.includes("second")
      );
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

    test("unit 4 supplement: local filter searches the whole list beyond the top-tag cap", async function (assert) {
      this.siteSettings.max_tags_in_filter_list = 1;
      const items = [
        { id: 1, name: "first" },
        { id: 2, name: "second" },
      ];
      await render(<template><DSelectTagFilter @items={{items}} /></template>);
      await click(".d-select__trigger");
      await fillIn(".d-select__panel input", "second");
      assert
        .dom("[role='option']")
        .hasText(
          "second",
          "matching local rows are found even beyond the initial cap"
        );
    });

    test("unit 4 supplement: group single selection clears to null and forwards blocks and identity", async function (assert) {
      const value = tracked("Local area");
      const requests = sinon.spy();
      pretender.get("/tag_groups/filter/search", () => {
        requests();
        return response({ results: [{ name: "Server group" }] });
      });
      const onChange = (next) => {
        value.value = next;
      };
      const items = [
        { id: "Local area", name: "Local area" },
        { id: "Local kind", name: "Local kind" },
      ];
      await render(
        <template>
          <DSelectTagGroup
            @id="groups-field"
            @identifier="groups"
            @instanceContext={{hash field="groups"}}
            @items={{items}}
            @label="Groups"
            @multiple={{false}}
            @onChange={{onChange}}
            @value={{value.value}}
            @variant="button"
          >
            <:selection as |item|>
              <span class="custom-selection">Selected {{item.name}}</span>
            </:selection>
            <:item as |item|>
              <span class="custom-item">Pick {{item.name}}</span>
            </:item>
            <:footer>
              <span class="custom-footer">Footer</span>
            </:footer>
          </DSelectTagGroup>
        </template>
      );
      assert.dom("#groups-field").hasAttribute(
        "aria-label",
        i18n("d_select.label_with_value", {
          label: "Groups",
          value: "Local area",
        }),
        "id, label and held value reach the control"
      );
      assert
        .dom(".custom-selection")
        .hasText("Selected Local area", "selection block is forwarded");
      await click(".d-select__trigger");
      assert
        .dom(".custom-item")
        .exists({ count: 2 }, "local item blocks are forwarded");
      assert.false(requests.called, "local groups never search the server");
      assert
        .dom(".custom-footer")
        .hasText("Footer", "footer block is forwarded");
      await new DSelect().close();
      await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");
      assert.strictEqual(value.value, null, "single group clearing emits null");
    });
    test("unit 4 supplement: clearing a single filter emits the all-tags shortcut", async function (assert) {
      const value = { id: 2, name: "other", slug: "other" };
      const onChange = sinon.spy();
      await render(
        <template>
          <DSelectTagFilter @onChange={{onChange}} @value={{value}} />
        </template>
      );
      await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");
      assert.strictEqual(
        onChange.lastCall?.args[0],
        "all-tags",
        "clearing normalizes to the all-tags id"
      );
    });

    test("unit 4 supplement: custom loaders still apply exclusion and the zero site cap", async function (assert) {
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

    test("unit 4 supplement: local creation needs both permissions and does not recreate excluded tags", async function (assert) {
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
    test("unit 4 supplement: single creation replaces a held tag at the site cap", async function (assert) {
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

    test("unit 4 supplement: functional local sources receive options and match stored names", async function (assert) {
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
  }
);
