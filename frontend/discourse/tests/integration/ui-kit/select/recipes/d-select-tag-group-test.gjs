import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import {
  click,
  find,
  findAll,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TagGroupList from "discourse/admin/components/site-settings/tag-group-list";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import { resetTagSourceCache } from "discourse/lib/tag-source";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectTagGroup from "discourse/ui-kit/select/recipes/tags/d-select-tag-group";
import { i18n } from "discourse-i18n";

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

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

module(
  "Integration | ui-kit | select | recipes | DSelectTagGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    test("a multiple group picker can still cap its selection", async function (assert) {
      this.siteSettings.max_tag_search_results = 5;
      pretender.get("/tag_groups/filter/search", () =>
        response({
          results: [
            { name: "Area", tags: [] },
            { name: "Kind", tags: [] },
          ],
        })
      );
      await render(
        <template>
          <DSelectTagGroup
            @maximum={{1}}
            @multiple={{true}}
            @value={{array "Area"}}
          />
        </template>
      );
      await click(".d-select__trigger");
      assert
        .dom(".d-select__limit")
        .exists("the multiple-selection cap is reached");
      assert
        .dom(optionNamed("Kind"))
        .hasAttribute("aria-disabled", "true", "another group cannot be added");
    });

    module("names and classes", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
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

      test("names in, names out, with the legacy classes", async function (assert) {
        const onChange = sinon.spy();
        const held = ["Area"];

        await render(
          <template>
            <DSelectTagGroup
              @multiple={{true}}
              @onChange={{onChange}}
              @value={{held}}
            />
          </template>
        );

        assert.dom(".d-select").hasClass("tag-group-chooser");
        assert.dom(".d-select").hasClass("tag-chooser");
        await click(".d-select__trigger");
        await click(optionNamed("Kind"));

        assert.deepEqual(onChange.lastCall.args[0], ["Area", "Kind"]);
      });

      test("a held group stays listed, marked selected", async function (assert) {
        const held = ["Area"];

        await render(
          <template>
            <DSelectTagGroup @multiple={{true}} @value={{held}} />
          </template>
        );
        await click(".d-select__trigger");

        const area = optionNamed("Area");
        assert.notStrictEqual(area, undefined, "the held group is listed");
        assert.strictEqual(area?.getAttribute("aria-selected"), "true");
        assert.strictEqual(
          optionNamed("Kind").getAttribute("aria-selected"),
          "false"
        );
      });

      test("single mode emits one name", async function (assert) {
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

      test("without @multiple, a picker holds one group", async function (assert) {
        const onChange = sinon.spy();

        await render(
          <template><DSelectTagGroup @onChange={{onChange}} /></template>
        );
        await click(".d-select__trigger");
        await click(optionNamed("Kind"));

        assert.strictEqual(onChange.lastCall.args[0], "Kind");
      });

      test("suppressFooter: no footer region without a caller footer", async function (assert) {
        await render(
          <template><DSelectTagGroup @multiple={{true}} /></template>
        );
        await click(".d-select__trigger");

        assert.dom(optionNamed("Kind")).exists("the panel is open");
        assert
          .dom(".d-select__footer")
          .doesNotExist("no empty footer region below the list");
      });

      test("held names that search does not return still show by name", async function (assert) {
        const held = ["Retired"];

        await render(
          <template>
            <div class="multiple-host">
              <DSelectTagGroup @multiple={{true}} @value={{held}} />
            </div>
            <div class="single-host">
              <DSelectTagGroup @multiple={{false}} @value="Retired" />
            </div>
          </template>
        );

        assert.dom(".multiple-host .d-select__chip").includesText("Retired");
        assert
          .dom(".multiple-host .d-select__chip")
          .doesNotIncludeText("Unknown item");
        assert.dom(".single-host .d-select__trigger").includesText("Retired");
        assert
          .dom(".single-host .d-select__trigger")
          .doesNotIncludeText("Unknown item");
      });
    });

    module("default names", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tag_search_results = 5;
      });

      test("a single picker is named Tag group", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(<template><DSelectTagGroup /></template>);

        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          i18n("tagging.tag_group_label")
        );
      });

      test("a multiple picker is named Tag groups", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(
          <template><DSelectTagGroup @multiple={{true}} /></template>
        );

        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          i18n("tagging.tag_groups_label")
        );
      });

      test("a multiple picker that holds one group is named Tag group", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <DSelectTagGroup @maximum={{1}} @multiple={{true}} />
          </template>
        );

        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          i18n("tagging.tag_group_label")
        );
      });

      test("@ariaLabelledBy names it after a visible caption", async function (assert) {
        const accessibleName = await loadAccessibleName();

        await render(
          <template>
            <span id="group-caption">Required groups</span>
            <DSelectTagGroup
              @ariaLabelledBy="group-caption"
              @multiple={{true}}
            />
          </template>
        );

        assert.strictEqual(
          accessibleName(find("[role='combobox']")),
          "Required groups"
        );
      });
    });

    module("texts", function () {
      test("the placeholder defaults to the select's own, and @texts or a customization replaces it", async function (assert) {
        stubGroupSearch();
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) =>
            value.forIdentifier("custom-groups", (spec) =>
              spec.options(() => ({ texts: { placeholder: "Any group" } }))
            )
          )
        );

        await render(
          <template>
            <div class="default"><DSelectTagGroup @multiple={{true}} /></div>
            <div class="call-site"><DSelectTagGroup
                @multiple={{true}}
                @texts={{hash placeholder="Pick groups"}}
              /></div>
            <div class="custom"><DSelectTagGroup
                @identifier="custom-groups"
                @multiple={{true}}
              /></div>
          </template>
        );

        assert
          .dom(".default [role='combobox']")
          .hasAttribute("placeholder", i18n("d_select.add_placeholder"));
        assert
          .dom(".call-site [role='combobox']")
          .hasAttribute("placeholder", "Pick groups");
        assert
          .dom(".custom [role='combobox']")
          .hasAttribute("placeholder", "Any group");
      });
    });

    module("local items and blocks", function (nestedHooks) {
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

      test("group single selection clears to null and forwards blocks and identity", async function (assert) {
        const value = tracked("Local area");
        pretender.get("/tag_groups/filter/search", () =>
          response({
            results: [{ name: "Local area" }, { name: "Local kind" }],
          })
        );
        const onChange = (next) => {
          value.value = next;
        };
        await render(
          <template>
            <DSelectTagGroup
              @id="groups-field"
              @identifier="groups"
              @instanceContext={{hash field="groups"}}
              @multiple={{false}}
              @onChange={{onChange}}
              @texts={{hash ariaLabel="Groups"}}
              @value={{value.value}}
              @variant="button"
            >
              <:selection as |item|>
                <span class="custom-selection">Selected {{item.name}}</span>
              </:selection>
              <:item as |item options row|>
                <span class="custom-item {{if row 'has-row'}}">Pick
                  {{item.name}}</span>
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
          .exists({ count: 2 }, "item blocks are forwarded");
        assert
          .dom(".custom-item.has-row")
          .exists({ count: 2 }, "the item block receives each row's state");
        assert
          .dom(".custom-footer")
          .hasText("Footer", "footer block is forwarded");
        await new DSelect().close();
        await triggerKeyEvent(".d-select__trigger", "keydown", "Backspace");
        assert.strictEqual(
          value.value,
          null,
          "single group clearing emits null"
        );
      });
    });

    module("TagGroupList new select controls", function () {
      test("picking a group reports pipe-joined names", async function (assert) {
        this.siteSettings.enable_new_select_controls = true;
        stubGroupSearch();
        withPluginApi((api) =>
          api.registerValueTransformer("select-customizations", ({ value }) => {
            value.forKind("select-tag-group", (spec) =>
              spec.row((row) => row.classes.push("x-select-tag-group"))
            );
          })
        );
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
        assert
          .dom("[role='option'].x-select-tag-group")
          .exists("uses the new group recipe");
        await click(optionNamed("Kind"));

        assert.deepEqual(changes, ["Area|Kind"]);
      });
    });
  }
);
