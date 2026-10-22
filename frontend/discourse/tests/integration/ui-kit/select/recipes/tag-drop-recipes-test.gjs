import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
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
