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
  triggerKeyEvent,
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
