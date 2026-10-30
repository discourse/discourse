import { array } from "@ember/helper";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SchemaSettingField from "discourse/admin/components/schema-setting/field";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSettingTagList from "discourse/admin/components/site-settings/tag-list";
import SiteSetting from "discourse/admin/models/site-setting";
import BreadCrumbs from "discourse/components/bread-crumbs";
import Form from "discourse/components/form";
import SearchAdvancedOptions from "discourse/components/search-advanced-options";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import TagSettings from "discourse/components/tag-settings";
import UserPreferencesTags from "discourse/components/user-preferences/tags";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import GroupManageTags from "discourse/templates/group/manage/tags";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect as SelectDriver } from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
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
  "Integration | ui-kit | select | recipes | tag call sites",
  function (hooks) {
    setupRenderingTest(hooks);

    module("notification preferences", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
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
        assert
          .dom(".tag-notifications .d-select.select-tag")
          .exists({ count: 4 });
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

        assert
          .dom(".groups-notifications-form .d-select.select-tag")
          .exists({ count: 5 });
        assert.dom(".groups-notifications-form .select-kit").doesNotExist();
      });
    });

    module(
      "FormKit, settings, search, breadcrumbs and tag settings",
      function (nestedHooks) {
        nestedHooks.beforeEach(function () {
          this.siteSettings.enable_new_select_controls = true;
          this.categories = [];
          this.siteSettings.tagging_enabled = true;
          this.siteSettings.max_tags_per_topic = 5;
          this.siteSettings.max_tags_in_filter_list = 30;
          this.site.set("top_tags", TOP_TAGS);
          this.routeTo = sinon.stub(DiscourseURL, "routeTo");
          this.routeToUrl = sinon.stub(DiscourseURL, "routeToUrl");
          stubSearch();
        });

        test("FormKit single replacement keeps an array with consistent tag ids", async function (assert) {
          const data = { foo: [{ id: 2, name: "ui" }] };
          const onSubmit = sinon.spy();
          await render(
            <template>
              <Form @data={{data}} @onSubmit={{onSubmit}} as |form|>
                <form.Field
                  @name="foo"
                  @title="Foo"
                  @type="tag-chooser"
                  as |field|
                >
                  <field.Control @maximum={{1}} />
                </form.Field>
              </Form>
            </template>
          );
          assert.dom(".d-select__trigger").doesNotHaveClass("--multiple");
          await formKit().field("foo").selectByName("bug");
          await formKit().submit();
          assert.deepEqual(
            onSubmit.lastCall.args[0].foo,
            [ROWS[0]],
            "replaces the held object in its array boundary"
          );
        });

        test("tag-list settings store original names from translated results", async function (assert) {
          stubSearch([{ id: 1, name: "戦略", original_name: "strategy" }]);
          const change = sinon.spy();
          await render(
            <template>
              <SiteSettingTagList @changeValueCallback={{change}} @value="" />
            </template>
          );
          await click(".d-select__trigger");
          await click(optionNamed("戦略"));
          assert.true(
            change.calledOnceWithExactly("strategy"),
            "the setting stores its canonical name"
          );
        });

        test("advanced search uses stored names from translated tags", async function (assert) {
          stubSearch([{ id: 1, name: "戦略", original_name: "strategy" }]);
          const change = sinon.spy();
          await render(
            <template>
              <SearchAdvancedOptions
                @expandFilters={{true}}
                @onChangeSearchTerm={{change}}
                @searchTerm=""
              />
            </template>
          );
          await new SelectDriver("#search-with-tags").open();
          await click(optionNamed("戦略"));
          assert.true(
            change.calledWithExactly("tags:strategy"),
            "the query uses a stored tag name"
          );
        });

        test("breadcrumb tag picks navigate through the synonym target and category scope", async function (assert) {
          this.site.set("top_tags", [
            {
              id: 8,
              name: "alias",
              slug: "alias",
              target_tag: { id: 9, name: "canonical", slug: "canonical-slug" },
            },
          ]);
          const category = {
            id: 7,
            path: "/c/support/7",
            ancestors: [],
            default_list_filter: "none",
          };
          await render(
            <template>
              <BreadCrumbs
                @categories={{this.categories}}
                @category={{category}}
              />
            </template>
          );
          await click(".tag-drop.d-select");
          await click(optionNamed("alias"));
          assert.true(
            this.routeToUrl.calledOnceWithExactly(
              "/tags/c/support/7/all/canonical-slug/9"
            ),
            "uses the target row and includes subcategories"
          );
        });

        test("breadcrumb shortcuts preserve no-subcategory routes", async function (assert) {
          const category = { id: 7, path: "/c/support/7", ancestors: [] };
          const tag = { id: 1, name: "alpha", slug: "alpha" };
          await render(
            <template>
              <BreadCrumbs
                @categories={{this.categories}}
                @category={{category}}
                @noSubcategories={{true}}
                @tag={{tag}}
              />
            </template>
          );
          await click(".tag-drop.d-select");
          await click(optionNamed(i18n("tagging.selector_no_tags")));
          assert.true(
            this.routeToUrl.calledWithExactly("/tags/c/support/7/none/none"),
            "untagged stays in the selected category scope"
          );
          await click(".tag-drop.d-select");
          await click(optionNamed(i18n("tagging.selector_remove_filter")));
          assert.true(
            this.routeToUrl.calledWithExactly("/c/support/7/none"),
            "all tags clears only the tag filter"
          );
        });

        test("customizations reach the breadcrumbs' tag drops by identifier", async function (assert) {
          withPluginApi((api) =>
            api.registerValueTransformer(
              "select-customizations",
              ({ value }) => {
                value.forIdentifier("breadcrumb-tag", (spec) =>
                  spec.options(() => ({ texts: { placeholder: "tag level" } }))
                );
                value.forIdentifier("breadcrumb-tag-intersection", (spec) =>
                  spec.row((row) => row.classes.push("x-intersection"))
                );
              }
            )
          );
          const main = { id: 2, name: "ui", slug: "ui" };
          await render(
            <template>
              <div class="single"><BreadCrumbs
                  @categories={{this.categories}}
                /></div>
              <div class="intersection"><BreadCrumbs
                  @additionalTags={{array "perf"}}
                  @categories={{this.categories}}
                  @tag={{main}}
                /></div>
            </template>
          );

          assert
            .dom(".single .tag-drop .d-select__placeholder")
            .hasText("tag level");
          assert
            .dom(".single .category-drop .d-select__placeholder")
            .doesNotHaveTextContaining("tag level", "not the category drop");
          await click(".intersection .tags-intersection-chooser.d-select");
          assert.dom("[role='option']").exists("the intersection drop is open");
          assert.true(
            findAll("[role='option']").every((row) =>
              row.classList.contains("x-intersection")
            ),
            "the intersection drop's rows"
          );
        });

        test("breadcrumb intersections keep the main tag first", async function (assert) {
          const main = { id: 2, name: "ui", slug: "translated-ui" };
          await render(
            <template>
              <BreadCrumbs
                @additionalTags={{array "perf"}}
                @categories={{this.categories}}
                @tag={{main}}
              />
            </template>
          );
          assert
            .dom(".tags-intersection-chooser")
            .hasAttribute("data-name", "ui,perf");
          await click(".tags-intersection-chooser.d-select");
          await click(optionNamed("bug"));
          assert.true(
            this.routeTo.calledOnceWithExactly(
              "/tags/intersection/ui/perf/bug"
            ),
            "main tag precedes held and newly picked tags"
          );
        });

        test("removing intersection tags restores the main tag slug route or a remaining name route", async function (assert) {
          const main = { id: 2, name: "ui", slug: "translated-ui" };
          await render(
            <template>
              <BreadCrumbs
                @additionalTags={{array "perf"}}
                @categories={{this.categories}}
                @tag={{main}}
              />
            </template>
          );
          await new SelectDriver(".tags-intersection-chooser.d-select").remove(
            "tag-name:perf"
          );
          assert.true(
            this.routeTo.calledWithExactly("/tag/translated-ui/2"),
            "the main tag uses its slug and id"
          );
          await new SelectDriver(".tags-intersection-chooser.d-select").remove(
            2
          );
          assert.true(
            this.routeTo.calledWithExactly("/tag/perf"),
            "a name-only additional tag uses the legacy name route"
          );
        });

        test("removing the final intersection tag navigates to tags", async function (assert) {
          await render(
            <template>
              <BreadCrumbs
                @additionalTags={{array "perf"}}
                @categories={{this.categories}}
              />
            </template>
          );
          await new SelectDriver(".tags-intersection-chooser.d-select").remove(
            "tag-name:perf"
          );
          assert.true(
            this.routeTo.calledOnceWithExactly("/tags"),
            "no tags means the tags index"
          );
        });

        test("tag settings search and transition by slug without loading every tag", async function (assert) {
          const store = this.owner.lookup("service:store");
          const findAllTags = sinon.spy(store, "findAll");
          const router = this.owner.lookup("service:router");
          const transitionTo = sinon.stub(router, "transitionTo");
          stubSearch([{ id: 9, name: "translated", slug: "stored-slug" }]);
          const tag = {
            id: 1,
            name: "alpha",
            slug: "alpha",
            synonyms: [],
            can_admin: false,
          };
          await render(
            <template>
              <TagSettings @selectedTab="general" @tag={{tag}} />
            </template>
          );
          assert.false(
            findAllTags.called,
            "the new branch does not fetch all tags"
          );
          const select = new SelectDriver(".tag-dropdown.d-select");
          await select.search("translated");
          await select.selectByName("translated");
          assert.true(
            transitionTo.calledWithExactly(
              "tag.edit.tab",
              "stored-slug",
              9,
              "general"
            ),
            "routing uses the server row's slug and id"
          );
        });
      }
    );

    module("names", function (nameHooks) {
      nameHooks.beforeEach(async function () {
        this.siteSettings.enable_new_select_controls = true;
        this.siteSettings.tagging_enabled = true;
        this.siteSettings.max_tags_per_topic = 5;
        stubSearch();
        pretender.get("/tag_groups/filter/search", () =>
          response({ results: [] })
        );
        this.nameOf = await loadAccessibleName();
      });

      /** Asserts the picker in `container` is named by the caption found there. */
      function assertNamedByCaption(assert, nameOf, container, caption) {
        const control = container.querySelector("[role='combobox']");
        assert.strictEqual(
          nameOf(control),
          container.querySelector(caption).textContent.trim(),
          container.className
        );
      }

      test("each preferences tag list is named by its caption", async function (assert) {
        const model = {
          watched_tags: [],
          tracked_tags: [],
          watching_first_post_tags: [],
          muted_tags: [],
          set() {},
        };
        const siteSettings = this.siteSettings;
        await render(
          <template>
            <UserPreferencesTags
              @model={{model}}
              @siteSettings={{siteSettings}}
            />
          </template>
        );

        const lists = findAll(".tracking-controls");
        assert.strictEqual(lists.length, 4);
        for (const list of lists) {
          assertNamedByCaption(assert, this.nameOf, list, "label");
        }
      });

      test("each group tag list is named by its caption", async function (assert) {
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

        const groups = findAll(".control-group").filter((group) =>
          group.querySelector(".d-select")
        );
        assert.strictEqual(groups.length, 5);
        for (const group of groups) {
          assertNamedByCaption(assert, this.nameOf, group, "label");
        }
      });

      test("the tag synonyms form field is named by its title", async function (assert) {
        const tag = {
          id: 1,
          name: "alpha",
          slug: "alpha",
          synonyms: [],
          can_admin: false,
        };
        await render(
          <template>
            <TagSettings @selectedTab="general" @tag={{tag}} />
          </template>
        );

        assertNamedByCaption(
          assert,
          this.nameOf,
          find(".form-kit__field[data-name='synonyms']"),
          ".form-kit__container-title > span"
        );
      });

      for (const type of ["tag_list", "tag_group_list"]) {
        test(`a ${type} site setting is named by its heading`, async function (assert) {
          const setting = SiteSetting.create({
            category: "foo",
            default: "",
            description: "",
            humanized_name: "Picked here",
            setting: "picked_here",
            type,
            value: "",
          });
          await render(
            <template><SiteSettingComponent @setting={{setting}} /></template>
          );

          assert.strictEqual(
            this.nameOf(find(".setting [role='combobox']")),
            "Picked here"
          );
        });

        test(`a ${type} form field is named by its title`, async function (assert) {
          const definition = { key: "picked", label: "Picked here", type };
          await render(
            <template>
              <Form as |form|>
                <SettingDefinitionField
                  @definition={{definition}}
                  @form={{form}}
                />
              </Form>
            </template>
          );

          assertNamedByCaption(
            assert,
            this.nameOf,
            find(".form-kit__field"),
            ".form-kit__container-title > span"
          );
        });
      }

      test("a tags schema field is named by its label", async function (assert) {
        const setting = {};
        const spec = { type: "tags" };
        const noop = () => {};
        await render(
          <template>
            <SchemaSettingField
              @label="Picked here"
              @name="picked"
              @onValueChange={{noop}}
              @setting={{setting}}
              @spec={{spec}}
            />
          </template>
        );

        assertNamedByCaption(
          assert,
          this.nameOf,
          find(".schema-field"),
          ".schema-field__label"
        );
      });
    });
  }
);
