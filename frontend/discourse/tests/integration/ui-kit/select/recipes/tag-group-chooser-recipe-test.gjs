import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TagGroupList from "discourse/admin/components/site-settings/tag-group-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DTagGroupChooser from "discourse/ui-kit/select/recipes/tags/d-tag-group-chooser";

/** Stubs tag group search, recording each request's query params. */
function stubGroupSearch() {
  const requests = [];
  pretender.get("/tag_groups/filter/search", (request) => {
    requests.push(request.queryParams);
    return response({
      results: [
        { name: "Kind", tags: [] },
        { name: "Area", tags: [] },
      ],
    });
  });
  return requests;
}

function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

module(
  "Integration | ui-kit | select | recipes | DTagGroupChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.tagging_enabled = true;
      this.siteSettings.max_tag_search_results = 5;
    });

    test("it is a tag-group-chooser kind keyed by name", async function (assert) {
      const requests = stubGroupSearch();
      const onChange = sinon.spy();
      await render(
        <template>
          <DTagGroupChooser
            @onChange={{onChange}}
            @tagGroups={{array "Area"}}
          />
        </template>
      );

      assert
        .dom(".d-select.tag-group-chooser")
        .hasAttribute("data-name", "Area");
      await click(".d-select__trigger");
      assert.strictEqual(requests.at(-1).limit, "5");
      await click(optionNamed("Kind"));

      assert.deepEqual(
        onChange.lastCall.args[0],
        ["Area", "Kind"],
        "names in, names out"
      );
    });

    test("a maximum of one keeps a single group", async function (assert) {
      stubGroupSearch();
      const onChange = sinon.spy();
      await render(
        <template>
          <DTagGroupChooser
            @maximum={{1}}
            @onChange={{onChange}}
            @tagGroups={{array "Area"}}
          />
        </template>
      );
      await click(".d-select__trigger");

      assert.dom(".d-select__limit").exists("the cap is reached");
    });
  }
);

module(
  "Integration | Component | SiteSettings | TagGroupList new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    test("picking a group reports pipe-joined names", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      stubGroupSearch();
      const value = tracked("Area");
      const changes = [];
      const changeValue = (next) => {
        changes.push(next);
        value.value = next;
      };

      await render(
        <template>
          <TagGroupList
            @changeValueCallback={{changeValue}}
            @value={{value.value}}
          />
        </template>
      );
      await click(".d-select__trigger");
      await click(optionNamed("Kind"));

      assert.deepEqual(changes, ["Area|Kind"]);
    });
  }
);
