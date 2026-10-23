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
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import UserPreferencesTags from "discourse/components/user-preferences/tags";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import GroupManageTags from "discourse/templates/group/manage/tags";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DMiniTagChooser from "discourse/ui-kit/select/recipes/tags/d-mini-tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import DSelectTagFilter, {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";
import DTagDrop from "discourse/ui-kit/select/recipes/tags/d-tag-drop";
import DTagDropdown from "discourse/ui-kit/select/recipes/tags/d-tag-dropdown";
import DTagsIntersectionChooser from "discourse/ui-kit/select/recipes/tags/d-tags-intersection-chooser";
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

/** A controlled tag field, as a call site would own it. */
class TagHost extends Component {
  @tracked tags = this.args.tags ?? [];

  @action
  onChange(tags) {
    this.args.onChange?.(tags);
    this.tags = tags;
  }

  <template>
    <DTagChooser
      @allowCreate={{@allowCreate}}
      @blockedTags={{@blockedTags}}
      @categoryId={{@categoryId}}
      @everyTag={{@everyTag}}
      @onChange={{this.onChange}}
      @tags={{this.tags}}
      @unlimitedTagCount={{@unlimitedTagCount}}
    />
  </template>
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

module(
  "Integration | ui-kit | select | recipes | DTagChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_search_results = 5;
      getOwner(this).lookup("service:site").set("can_create_tag", true);
    });

    test("it is a tag-chooser kind with the legacy family class", async function (assert) {
      stubSearch();
      const kinds = [];
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) => {
          value.forKind("tag-chooser", (spec) =>
            spec.row((row) => {
              kinds.push("tag-chooser");
              row.classes.push("x-tag-kind");
            })
          );
        })
      );

      await render(<template><TagHost /></template>);
      await click(".d-select__trigger");

      assert
        .dom(".d-select.tag-chooser")
        .exists("keeps the legacy family class");
      assert.true(
        kinds.length > 0,
        "customizations target the tag-chooser kind"
      );
      assert.dom("[role='option'].x-tag-kind").exists();
    });

    test("search sends the category, held and blocked ids", async function (assert) {
      const requests = stubSearch();

      await render(
        <template>
          <TagHost
            @blockedTags={{array (hash id=9 name="blocked")}}
            @categoryId={{7}}
            @tags={{array (hash id=2 name="ui")}}
          />
        </template>
      );
      await click(".d-select__trigger");

      const params = requests.at(-1);
      const selected = params["selected_tag_ids[]"] ?? params.selected_tag_ids;
      assert.strictEqual(params.categoryId, "7");
      assert.deepEqual([...selected].sort(), ["2", "9"]);
      assert.strictEqual(
        params.filterForInput,
        "true",
        "input rules apply by default"
      );
    });

    test("everyTag lists every tag", async function (assert) {
      const requests = stubSearch();

      await render(<template><TagHost @everyTag={{true}} /></template>);
      await click(".d-select__trigger");

      assert.strictEqual(requests.at(-1).filterForInput, undefined);
    });

    test("rows are tags without links, counts hidden from the name", async function (assert) {
      stubSearch();

      await render(<template><TagHost /></template>);
      await click(".d-select__trigger");

      const bug = optionNamed("bug");
      assert.dom(bug.querySelector(".discourse-tag")).exists("renders the tag");
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
          <TagHost @onChange={{onChange}} @tags={{array held}} />
        </template>
      );
      await click(".d-select__trigger");
      await click(optionNamed("bug"));

      const [tags] = onChange.lastCall.args;
      assert.strictEqual(tags[0], held, "the held object passes through");
      assert.deepEqual(tags[1], ROWS[0], "the picked row is the server row");
    });

    test("held names emit as names", async function (assert) {
      stubSearch();
      pretender.get("/tags/list.json", () => response({ list_tags: [] }));
      const onChange = sinon.spy();

      await render(
        <template>
          <TagHost @onChange={{onChange}} @tags={{array "foo"}} />
        </template>
      );
      assert.dom(".d-select__chip").hasText(/foo/);

      await click(".d-select__trigger");
      await click(optionNamed("bug"));

      assert.deepEqual(onChange.lastCall.args[0], [{ name: "foo" }, ROWS[0]]);
    });

    test("a permitted create adds a new tag", async function (assert) {
      stubSearch();
      const onChange = sinon.spy();

      await render(
        <template>
          <TagHost @allowCreate={{true}} @onChange={{onChange}} />
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

    test("fix oracle: pasting pipe-separated names adds each tag", async function (assert) {
      stubSearch();
      const onChange = sinon.spy();

      await render(
        <template>
          <TagHost @allowCreate={{true}} @onChange={{onChange}} />
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
      assert.dom(input).hasValue("", "the pasted text is not left as a query");
    });

    test("create needs both the call site and the permission", async function (assert) {
      stubSearch();
      getOwner(this).lookup("service:site").set("can_create_tag", false);

      await render(<template><TagHost @allowCreate={{true}} /></template>);
      await click(".d-select__trigger");
      await fillIn("[role='combobox']", "newtag");

      assert.dom("[role='option'].--create").doesNotExist();
    });

    test("a forbidden term offers no create row", async function (assert) {
      stubSearch([], { forbidden: "evil", forbidden_message: "No" });

      await render(<template><TagHost @allowCreate={{true}} /></template>);
      await click(".d-select__trigger");
      await fillIn("[role='combobox']", "evil");

      assert.dom("[role='option'].--create").doesNotExist();
    });

    test("blocked tags never appear as rows", async function (assert) {
      stubSearch();

      await render(
        <template><TagHost @blockedTags={{array "perf"}} /></template>
      );
      await click(".d-select__trigger");

      assert.strictEqual(optionNamed("perf"), undefined);
      assert.notStrictEqual(optionNamed("bug"), undefined);
    });

    test("the tag cap follows the site setting unless unlimited", async function (assert) {
      stubSearch();
      this.siteSettings.max_tags_per_topic = 1;

      await render(
        <template><TagHost @tags={{array (hash id=2 name="ui")}} /></template>
      );
      await click(".d-select__trigger");
      assert.dom(".d-select__limit").exists("the cap applies");

      await render(
        <template>
          <TagHost
            @tags={{array (hash id=2 name="ui")}}
            @unlimitedTagCount={{true}}
          />
        </template>
      );
      await click(".d-select__trigger");
      assert.dom(".d-select__limit").doesNotExist("no cap when unlimited");
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

      await render(<template><TagHost /></template>);
      await click(".d-select__trigger");

      assert.dom(optionNamed("child")).hasAttribute("aria-disabled", "true");
      assert.dom(optionNamed("child")).includesText("Requires parent");
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | tag chooser call sites",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      stubSearch();
    });

    test("user preference tags switch with the flag", async function (assert) {
      const model = {
        watched_tags: [],
        tracked_tags: [],
        watching_first_post_tags: [],
        muted_tags: [],
        set() {},
      };
      const siteSettings = this.siteSettings;

      siteSettings.enable_new_select_controls = true;
      await render(
        <template>
          <UserPreferencesTags
            @model={{model}}
            @siteSettings={{siteSettings}}
          />
        </template>
      );
      assert.dom(".tag-notifications .d-select").exists({ count: 4 });
      assert.dom(".tag-notifications .select-kit").doesNotExist();

      siteSettings.enable_new_select_controls = false;
      await settled();
      await render(
        <template>
          <UserPreferencesTags
            @model={{model}}
            @siteSettings={{siteSettings}}
          />
        </template>
      );
      assert.dom(".tag-notifications .select-kit").exists({ count: 4 });
    });

    test("user preference tags write the same shape in both modes", async function (assert) {
      const set = sinon.spy();
      const model = {
        watched_tags: [],
        tracked_tags: [],
        watching_first_post_tags: [],
        muted_tags: [],
        set,
      };
      this.siteSettings.enable_new_select_controls = true;
      const siteSettings = this.siteSettings;

      await render(
        <template>
          <UserPreferencesTags
            @model={{model}}
            @siteSettings={{siteSettings}}
          />
        </template>
      );
      await click(".tracking-controls__watched-tags .d-select__trigger");
      await click(optionNamed("bug"));

      assert.true(set.calledWith("watched_tags", [ROWS[0]]));
    });

    test("group tag settings switch with the flag", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      const controller = {
        siteSettings: this.siteSettings,
        selectedTags: [],
        model: {
          watching_tags: [],
          tracking_tags: [],
          watching_first_post_tags: [],
          regular_tags: [],
          muted_tags: [],
          set() {},
        },
      };

      await render(
        <template><GroupManageTags @controller={{controller}} /></template>
      );

      assert.dom(".groups-notifications-form .d-select").exists({ count: 5 });
      assert.dom(".groups-notifications-form .select-kit").doesNotExist();
    });
  }
);

/** A controlled mini tag field, as the composer owns it. */
class MiniTagHost extends Component {
  @tracked value = this.args.value ?? [];

  @action
  onChange(tags) {
    this.args.onChange?.(tags);
    this.value = tags;
  }

  <template>
    <DMiniTagChooser
      @categoryId={{@categoryId}}
      @minimum={{@minimum}}
      @onChange={{this.onChange}}
      @value={{this.value}}
    />
  </template>
}

module(
  "Integration | ui-kit | select | recipes | DMiniTagChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_search_results = 5;
      getOwner(this).lookup("service:site").set("can_create_tag", true);
      stubSearch();
    });

    test("it is a mini-tag-chooser kind with the legacy family class", async function (assert) {
      await render(<template><MiniTagHost /></template>);

      assert.dom(".d-select.mini-tag-chooser").exists();
    });

    test("creation follows the site permission by default", async function (assert) {
      const onChange = sinon.spy();
      await render(<template><MiniTagHost @onChange={{onChange}} /></template>);
      await click(".d-select__trigger");
      await fillIn("[role='combobox']", "fresh");

      assert.dom("[role='option'].--create").hasText("Create “fresh”");
    });

    test("fix oracle: Enter creates a typed tag once the list has changed", async function (assert) {
      const onChange = sinon.spy();
      await render(<template><MiniTagHost @onChange={{onChange}} /></template>);
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
      await render(<template><MiniTagHost @minimum={{2}} /></template>);

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
  }
);

const TOP_TAGS = [
  { id: 3, name: "zeta", slug: "zeta", count: 1 },
  { id: 1, name: "alpha", slug: "alpha", count: 5 },
];

module("Integration | ui-kit | select | recipes | DTagDrop", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.tagging_enabled = true;
    this.siteSettings.max_tags_in_filter_list = 30;
    this.siteSettings.max_tag_search_results = 5;
    this.siteSettings.tags_sort_alphabetically = false;
    getOwner(this).lookup("service:site").set("top_tags", TOP_TAGS);
    this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
  });

  test("it is a tag-drop single select with the legacy classes", async function (assert) {
    await render(<template><DTagDrop /></template>);

    assert.dom(".d-select.tag-drop").exists();
    assert.dom(".d-select.tag-drop").hasClass("tag_all", "no tag selected");
    assert
      .dom(".d-select")
      .hasAttribute("data-name", i18n("tagging.selector_tags"));
  });

  test("the empty list shows the shortcuts, then the top tags", async function (assert) {
    const tag = { id: 1, name: "alpha", slug: "alpha" };
    await render(<template><DTagDrop @tag={{tag}} /></template>);
    await click(".d-select__trigger");

    const names = findAll("[role='option']").map((row) =>
      row.textContent.trim()
    );
    assert.true(names[0].includes(i18n("tagging.selector_remove_filter")));
    assert.true(names[1].includes(i18n("tagging.selector_no_tags")));
    assert.true(names[2].includes("zeta"), "top tags keep their order");
    assert.dom(".d-select.tag-drop").hasClass("tag-alpha");
  });

  test("fix oracle: the shortcuts follow a changed tag", async function (assert) {
    const currentTag = tracked(null);
    await render(<template><DTagDrop @tag={{currentTag.value}} /></template>);
    await click(".d-select__trigger");
    assert.strictEqual(
      optionNamed(i18n("tagging.selector_remove_filter")),
      undefined,
      "no tag, nothing to remove"
    );
    await triggerKeyEvent(".d-select__trigger", "keydown", "Escape");

    currentTag.value = { id: 1, name: "alpha", slug: "alpha" };
    await settled();
    await click(".d-select__trigger");

    assert.notStrictEqual(
      optionNamed(i18n("tagging.selector_remove_filter")),
      undefined,
      "the remove filter shortcut appears"
    );
  });

  test("picking a tag routes to its filtered list", async function (assert) {
    await render(<template><DTagDrop /></template>);
    await click(".d-select__trigger");
    await click(optionNamed("alpha"));

    assert.true(this.routeToUrl.calledOnce);
    assert.true(
      /\/tag\/alpha/.test(this.routeToUrl.lastCall.args[0]),
      this.routeToUrl.lastCall.args[0]
    );
  });

  test("the no-tags shortcut routes to untagged topics", async function (assert) {
    await render(<template><DTagDrop /></template>);
    await click(".d-select__trigger");
    await click(optionNamed(i18n("tagging.selector_no_tags")));

    assert.true(
      /none/.test(this.routeToUrl.lastCall.args[0]),
      this.routeToUrl.lastCall.args[0]
    );
  });

  test("typing searches all tags", async function (assert) {
    const requests = stubSearch();
    await render(<template><DTagDrop /></template>);
    await click(".d-select__trigger");
    await fillIn(".d-select__filter, [role='combobox']", "bu");

    assert.strictEqual(requests.at(-1).q, "bu");
    assert.notStrictEqual(optionNamed("bug"), undefined);
  });

  test("a call site can supply its own tags and handler", async function (assert) {
    const onChange = sinon.spy();
    const items = [{ id: "local", name: "local", count: 2 }];
    await render(
      <template><DTagDrop @items={{items}} @onChange={{onChange}} /></template>
    );
    await click(".d-select__trigger");
    await click(optionNamed("local"));

    assert.true(onChange.calledOnce, "the call site's handler runs");
    assert.true(this.routeToUrl.notCalled, "instead of routing");
  });
});

module(
  "Integration | ui-kit | select | recipes | DTagsIntersectionChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.routeTo = sinon.stub(DiscourseURL, "routeTo");
      stubSearch();
    });

    test("it holds the main and additional tags and routes to their intersection", async function (assert) {
      const mainTag = { id: 2, name: "ui", slug: "ui" };
      const additionalTags = ["perf"];
      await render(
        <template>
          <DTagsIntersectionChooser
            @additionalTags={{additionalTags}}
            @mainTag={{mainTag}}
          />
        </template>
      );

      assert
        .dom(".d-select.tags-intersection-chooser")
        .hasAttribute("data-name", "ui,perf");
      await click(".d-select__trigger");
      await click(optionNamed("bug"));

      assert.strictEqual(
        this.routeTo.lastCall.args[0],
        "/tags/intersection/ui/perf/bug"
      );
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | DTagDropdown",
  function (hooks) {
    setupRenderingTest(hooks);

    test("picking a tag opens its settings", async function (assert) {
      const routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
      const tags = [
        { id: 1, name: "alpha" },
        { id: 2, name: "beta" },
      ];
      await render(
        <template><DTagDropdown @tags={{tags}} @value="alpha" /></template>
      );

      assert.dom(".d-select.tag-dropdown").hasAttribute("data-name", "alpha");
      await click(".d-select__trigger");
      await click(optionNamed("beta"));

      assert.strictEqual(
        routeToUrl.lastCall.args[0],
        "/tag/beta/2/edit/general"
      );
    });
  }
);

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

module(
  "Integration | ui-kit | select | recipes | DSelectTag",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tag_search_results = 5;
      getOwner(this).lookup("service:site").set("can_create_tag", true);
    });

    test("select tag: its kind is select-tag and its legacy class defaults to tag-chooser", async function (assert) {
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

    test("select tag: emits tag objects and accepts held names", async function (assert) {
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
      assert.strictEqual(emitted[1].id, 1, "the picked tag is its row object");
    });

    test("select tag: @emit=names emits stored names, never a translation", async function (assert) {
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

    test("select tag: an unknown @emit value throws in development", async function (assert) {
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

    test("select tag: creation needs both @allowCreate and the site permission", async function (assert) {
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
      await triggerKeyEvent(".allowed [role='combobox']", "keydown", "Escape");

      await click(".default .d-select__trigger");
      await fillIn(".default [role='combobox']", "newtag");
      assert
        .dom("[role='option'].--create")
        .doesNotExist("the site permission alone is not enough");
      await triggerKeyEvent(".default [role='combobox']", "keydown", "Escape");

      site.set("can_create_tag", false);
      await click(".allowed .d-select__trigger");
      await fillIn(".allowed [role='combobox']", "othertag");
      assert
        .dom("[role='option'].--create")
        .doesNotExist("the call site alone is not enough");
    });

    test("select tag: the site tag limit caps by default and false lifts it", async function (assert) {
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

    test("select tag: a site limit of 0 blocks additions but keeps removal; an explicit 0 does not", async function (assert) {
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

    test("select tag: single mode holds one tag, matched by name, and does not send it as selected", async function (assert) {
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
      assert.false(onChange.called, "re-picking the held tag is not a change");

      await click(".d-select__trigger");
      await click(optionNamed("bug"));
      assert.strictEqual(onChange.lastCall.args[0].id, 1, "one tag object");

      const selected = [].concat(requests.at(-1)?.selected_tag_ids ?? []);
      assert.false(selected.includes("2"), "the held tag is not sent");
    });

    test("select tag: @exclude still sends the excluded ids", async function (assert) {
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

    test("select tag: search options map onto the request", async function (assert) {
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

    test("select tag: @variant=button renders a button trigger", async function (assert) {
      stubSearch();

      await render(
        <template>
          <SelectTagHost @multiple={{false}} @variant="button" />
        </template>
      );

      assert.dom(".d-select__trigger").doesNotHaveClass("--typeahead");
      await click(".d-select__trigger");
      assert.dom(".d-select__panel input").exists("the search is in the panel");
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | DSelectTagFilter",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tags_per_topic = 5;
      this.siteSettings.max_tags_in_filter_list = 30;
      this.siteSettings.max_tag_search_results = 5;
      this.siteSettings.tags_sort_alphabetically = false;
      getOwner(this).lookup("service:site").set("top_tags", TOP_TAGS);
      this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
      this.routeTo = sinon.stub(DiscourseURL, "routeTo");
    });

    test("select tag filter: exports the shortcut values", function (assert) {
      assert.strictEqual(ALL_TAGS_ID, "all-tags");
      assert.strictEqual(NO_TAG_ID, "no-tags");
    });

    test("select tag filter: single mode keeps the legacy drop classes", async function (assert) {
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

    test("select tag filter: shortcuts first, then top tags; picks emit rows and never navigate", async function (assert) {
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

    test("select tag filter: the shortcuts emit their ids", async function (assert) {
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

    test("select tag filter: a tag named none reads as untagged", async function (assert) {
      const untagged = { name: "none" };

      await render(
        <template><DSelectTagFilter @value={{untagged}} /></template>
      );

      assert
        .dom(".d-select")
        .hasAttribute("data-name", i18n("tagging.selector_no_tags"));
    });

    test("select tag filter: multiple mode holds tags in order, by identity, with the intersection classes", async function (assert) {
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

    test("select tag filter: @items filters a local list", async function (assert) {
      const requests = stubSearch();
      const items = [
        { id: 7, name: "local-one" },
        { id: 8, name: "local-two" },
      ];

      await render(<template><DSelectTagFilter @items={{items}} /></template>);
      await click(".d-select__trigger");

      assert.notStrictEqual(optionNamed("local-one"), undefined);
      assert.strictEqual(requests.length, 0, "no search request");
    });
  }
);

module(
  "Integration | ui-kit | select | recipes | DSelectTagGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tag_search_results = 5;
      pretender.get("/tag_groups/filter/search", () =>
        response({
          results: [
            { name: "Kind", tags: [] },
            { name: "Area", tags: [] },
          ],
        })
      );
    });

    test("select tag group: names in, names out, with the legacy classes", async function (assert) {
      const onChange = sinon.spy();
      const held = ["Area"];

      await render(
        <template>
          <DSelectTagGroup @onChange={{onChange}} @value={{held}} />
        </template>
      );

      assert.dom(".d-select").hasClass("tag-group-chooser");
      assert.dom(".d-select").hasClass("tag-chooser");
      await click(".d-select__trigger");
      await click(optionNamed("Kind"));

      assert.deepEqual(onChange.lastCall.args[0], ["Area", "Kind"]);
    });

    test("select tag group: single mode emits one name", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelectTagGroup
            @multiple={{false}}
            @onChange={{onChange}}
            @value="Area"
          />
        </template>
      );
      await click(".d-select__trigger");
      await click(optionNamed("Kind"));

      assert.strictEqual(onChange.lastCall.args[0], "Kind");
    });
  }
);
