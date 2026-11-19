import { array, concat, hash } from "@ember/helper";
import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { paste } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | SettingDefinitionField", function (hooks) {
  setupRenderingTest(hooks);

  test("string falls back to a text input bound to the form", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_setting="hello"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_setting"
              type="string"
              label="My setting"
              description="A description"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_setting'] input").exists();
    assert
      .dom("[data-name='my_setting'] .form-kit__container-title")
      .containsText("My setting");
    assert.dom("[data-name='my_setting'] input").hasValue("hello");
  });

  test("an unsupported type also falls back to a text input", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_setting="x"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_setting"
              type="not_a_real_type"
              label="My setting"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_setting'] input").exists();
    assert.dom("[data-name='my_setting'] input").hasValue("x");
  });

  test("integer renders a number input with min/max", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_int="5"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_int"
              type="integer"
              label="My int"
              min=1
              max=10
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_int'] input").hasAttribute("type", "number");
    assert.dom("[data-name='my_int'] input").hasAttribute("min", "1");
    assert.dom("[data-name='my_int'] input").hasAttribute("max", "10");
    assert.dom("[data-name='my_int'] input").hasValue("5");
  });

  test("bool renders a checkbox with the description as its label and no title", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_bool=true}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_bool"
              type="bool"
              label="My bool"
              description="Enable the thing"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_bool'] input[type='checkbox']").exists();
    assert.dom("[data-name='my_bool']").containsText("Enable the thing");
    assert
      .dom("[data-name='my_bool'] .form-kit__container-title")
      .doesNotExist();
  });

  test("enum renders a select with the provided choices", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              choices=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_enum'] select option[value='a']").exists();
    assert.dom("[data-name='my_enum'] select option[value='b']").exists();
    assert.form().field("my_enum").hasValue("a");
  });

  test("duration is matched by subtype and renders a relative time picker", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_duration=2}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_duration"
              type="integer"
              subtype="duration"
              label="My duration"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_duration'] input.relative-time-duration")
      .exists();
  });

  test("group_list deserializes a pipe string and serializes the selection back", async function (assert) {
    this.site.groups = [
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="1"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_groups}}</span>
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_groups'] .list-setting");
    assert.strictEqual(
      groups.header().value(),
      "1",
      "deserializes the pipe string into the selected group"
    );

    await groups.expand();
    await groups.selectRowByValue("2");

    assert
      .dom(".value-probe")
      .hasText("1|2", "serializes the selection back to a pipe string");
  });

  test("group_list swaps everyone for logged_in_users when granular permissions are enabled", async function (assert) {
    this.siteSettings.granular_anonymous_and_logged_in_groups_permissions = true;

    this.site.groups = [
      { id: 1, name: "Donuts" },
      { id: 5, name: "logged_in_users" },
      { id: 11, name: "trust_level_1" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="0|11"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
              currentSavedValue="0|11"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_groups}}</span>
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_groups'] .list-setting");
    assert.strictEqual(
      groups.header().value(),
      "5,11",
      "displays logged_in_users instead of everyone"
    );
    assert
      .dom(".value-probe")
      .hasText("0|11", "does not rewrite the form value just by rendering");

    await groups.expand();
    await groups.selectRowByValue("1");

    assert
      .dom(".value-probe")
      .hasText("0|11|1", "maps logged_in_users back to everyone on write");
  });

  test("group_list keeps everyone in the value even when the definition has no saved-value reference", async function (assert) {
    this.siteSettings.granular_anonymous_and_logged_in_groups_permissions = true;

    this.site.groups = [
      { id: 1, name: "Donuts" },
      { id: 5, name: "logged_in_users" },
      { id: 11, name: "trust_level_1" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="0|11"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_groups}}</span>
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_groups'] .list-setting");
    await groups.expand();
    await groups.selectRowByValue("1");

    assert
      .dom(".value-probe")
      .hasText(
        "0|11|1",
        "falls back to the current value to keep everyone stored as everyone"
      );
  });

  test("group_list filters out disallowed groups from the choices", async function (assert) {
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
              disallowed_groups="0"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_groups'] .list-setting");
    await groups.expand();

    assert.false(groups.rowByValue("0").exists(), "disallowed group is hidden");
    assert.true(groups.rowByValue("1").exists());
    assert.true(groups.rowByValue("2").exists());
  });

  test("group_list marks mandatory values as non-removable", async function (assert) {
    this.site.groups = [
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="1"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
              mandatory_values="1"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_groups'] .list-setting");
    await groups.expand();

    assert
      .dom("[data-name='my_groups'] .selected-content button")
      .hasClass("disabled");
  });

  test("enum prefers valid_values over a raw string choices array (site setting shape)", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              choices=(array "a" "b")
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_enum'] select option[value='a']")
      .hasText("Apple");
    assert
      .dom("[data-name='my_enum'] select option[value='b']")
      .hasText("Banana");
    assert.form().field("my_enum").hasValue("a");
  });

  test("enum normalizes scalar choices into options", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              choices=(array "a" "b")
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_enum'] select option[value='a']").hasText("a");
    assert.dom("[data-name='my_enum'] select option[value='b']").hasText("b");
    assert.form().field("my_enum").hasValue("a");
  });

  test("enum does not select the first choice when the current value is invalid", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum="missing"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_enum'] select option[value='missing']")
      .hasText(
        i18n("admin.settings.none"),
        "the invalid value is presented as no selection"
      )
      .hasAttribute("disabled", "", "the invalid option cannot be selected");
    assert
      .form()
      .field("my_enum")
      .hasValue(
        "missing",
        "the browser does not select the first valid choice"
      );
  });

  test("enum only offers a none option when the setting allows a blank value", async function (assert) {
    await render(
      <template>
        <Form
          @data={{hash with_none="a" without_none="a" no_allows_none_key="a"}}
          as |form|
        >
          <SettingDefinitionField
            @definition={{hash
              key="with_none"
              type="enum"
              label="With none"
              valid_values=(array
                "" (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
          <SettingDefinitionField
            @definition={{hash
              key="without_none"
              type="enum"
              label="Without none"
              allows_none=false
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
          <SettingDefinitionField
            @definition={{hash
              key="no_allows_none_key"
              type="enum"
              label="Consumer default"
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='with_none'] select option[value='__NONE__']")
      .exists("the blank valid value becomes a none option");
    assert
      .dom("[data-name='with_none'] select option")
      .exists({ count: 3 }, "the raw blank entry does not render as an option");
    assert
      .dom("[data-name='without_none'] select option[value='__NONE__']")
      .doesNotExist(
        "a setting that does not allow a blank value cannot be cleared"
      );
    assert
      .dom("[data-name='no_allows_none_key'] select option[value='__NONE__']")
      .exists(
        "definitions without allows_none keep the optional-field default"
      );
  });

  test("enum matches the selected option when values are not strings", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum=5}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              valid_values=(array
                (hash value=5 name="Five") (hash value=6 name="Six")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.form().field("my_enum").hasValue("5");
  });

  test("compact_list offers created entries again after they are removed", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_list="a"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "a" "b")
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_list}}</span>
        </Form>
      </template>
    );

    const list = selectKit("[data-name='my_list'] .list-setting");
    await list.expand();
    await list.fillInFilter("custom");
    await list.keyboard("Enter");

    assert.dom(".value-probe").hasText("a|custom");

    await list.deselectItemByValue("custom");
    assert.dom(".value-probe").hasText("a");

    await list.collapse();
    await list.expand();
    assert.true(
      list.rowByValue("custom").exists(),
      "the created entry stays available as a choice"
    );
  });

  test("compact_list does not allow arbitrary entries when allow_any is false", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_list="a"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "a" "b")
              allow_any=false
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_list}}</span>
        </Form>
      </template>
    );

    const list = selectKit("[data-name='my_list'] .list-setting");
    await list.expand();
    await list.fillInFilter("custom");
    await list.keyboard("Enter");

    assert.dom(".value-probe").hasText("a");
  });

  test("compact_list marks mandatory values as non-removable", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_list="admin|moderator"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "admin" "moderator")
              mandatory_values="admin"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const list = selectKit("[data-name='my_list'] .list-setting");
    await list.expand();

    assert
      .dom("[data-name='my_list'] .selected-content button")
      .hasClass("disabled");
  });

  test("host_list adds typed hosts and ignores wildcards", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_hosts="a.com"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_hosts"
              type="host_list"
              label="My hosts"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_hosts}}</span>
        </Form>
      </template>
    );

    const hosts = selectKit("[data-name='my_hosts'] .list-setting");
    await hosts.expand();
    await hosts.fillInFilter("b.com");
    await hosts.keyboard("Enter");

    assert.dom(".value-probe").hasText("a.com|b.com");

    await hosts.fillInFilter("*.c.com");
    await hosts.keyboard("Enter");

    assert.dom(".value-probe").hasText("a.com|b.com", "ignores wildcard hosts");
  });

  for (const [type, extra] of [
    ["group_list", {}],
    ["category_list", {}],
    ["compact_list", {}],
    ["font_list", { choices: [{ value: "arial", name: "Arial" }] }],
    ["topic", {}],
    ["host_list", {}],
    ["group", {}],
    ["category", {}],
    ["tag_group_list", {}],
  ]) {
    test(`${type} is disabled with its field`, async function (assert) {
      const definition = {
        key: "my_setting",
        type,
        label: "My setting",
        ...extra,
      };

      await render(
        <template>
          <Form @data={{hash my_setting=""}} as |form|>
            <SettingDefinitionField
              @definition={{definition}}
              @disabled={{true}}
              @form={{form}}
            />
          </Form>
        </template>
      );

      assert
        .dom("[data-name='my_setting'] .select-kit")
        .hasClass("is-disabled");
    });
  }

  test("category_list clears every selection", async function (assert) {
    const categoryId = Site.current().categories[0].id;

    await render(
      <template>
        <Form @data={{hash my_categories=(concat categoryId)}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_categories"
              type="category_list"
              label="My categories"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_categories}}</span>
        </Form>
      </template>
    );

    const categories = selectKit(
      "[data-name='my_categories'] .category-selector"
    );
    await categories.expand();
    await categories.deselectItemByValue(categoryId);

    assert
      .dom(".value-probe")
      .hasText("", "removing the last category clears the value");
  });

  test("category serializes the selection as an id string", async function (assert) {
    const [category, otherCategory] = Site.current().categories;

    await render(
      <template>
        <Form @data={{hash my_category=(concat category.id)}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_category"
              type="category"
              label="My category"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_category}}</span>
        </Form>
      </template>
    );

    const categories = selectKit("[data-name='my_category'] .category-chooser");
    await categories.expand();
    await categories.selectRowByValue(otherCategory.id);

    assert.dom(".value-probe").hasText(String(otherCategory.id));
  });

  test("group filters out disallowed groups from the choices", async function (assert) {
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
    ];

    await render(
      <template>
        <Form @data={{hash my_group="1"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_group"
              type="group"
              label="My group"
              disallowed_groups="0"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_group}}</span>
        </Form>
      </template>
    );

    const groups = selectKit("[data-name='my_group'] .combo-box");
    assert.strictEqual(groups.header().value(), "1");

    await groups.expand();
    assert.false(groups.rowByValue("0").exists(), "everyone is not offered");
    assert.true(groups.rowByValue("1").exists());
  });

  test("tag_list round-trips a pipe-joined list of tag names", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_tags="dog|cat"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash key="my_tags" type="tag_list" label="My tags"}}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_tags}}</span>
        </Form>
      </template>
    );

    const tags = selectKit("[data-name='my_tags'] .tag-chooser");
    assert.strictEqual(tags.header().value(), "dog,cat");

    await tags.expand();
    await tags.selectRowByName("monkey");

    assert.dom(".value-probe").hasText("dog|cat|monkey");
  });

  test("tag_group_list round-trips a pipe-joined list of tag group names", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_tag_groups="TagGroup1"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_tag_groups"
              type="tag_group_list"
              label="My tag groups"
            }}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_tag_groups}}</span>
        </Form>
      </template>
    );

    const tagGroups = selectKit(
      "[data-name='my_tag_groups'] .tag-group-chooser"
    );
    await tagGroups.expand();
    await tagGroups.selectRowByName("TagGroup2");

    assert.dom(".value-probe").hasText("TagGroup1|TagGroup2");
  });

  test("icon offers icons that are not in the sprite yet", async function (assert) {
    let onlyAvailable;
    pretender.get("/svg-sprite/picker-search", (request) => {
      onlyAvailable = request.queryParams.only_available;
      return response(200, { icons: [{ id: "pencil" }], has_more: false });
    });

    await render(
      <template>
        <Form @data={{hash my_icon="heart"}} as |form|>
          <SettingDefinitionField
            @definition={{hash key="my_icon" type="icon" label="My icon"}}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_icon'] .d-icon-grid-picker")
      .hasAttribute("data-value", "heart");

    await click(".d-icon-grid-picker-trigger");
    await waitFor("[data-icon-id='pencil']");

    assert.strictEqual(
      onlyAvailable,
      "false",
      "an icon can be picked before it is rendered anywhere on the site"
    );
  });

  test("list + list_type collapses to the compact_list control", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_list="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="list"
              list_type="compact"
              label="My list"
              valid_values=(array
                (hash value="a" name="Alpha") (hash value="b" name="Beta")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_list'] .list-setting").exists();
    assert.dom("[data-name='my_list']").containsText("Alpha");
  });

  test("textarea renders a textarea with a placeholder", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_text=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_text"
              type="textarea"
              label="My text"
              placeholder="Type here"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_text'] textarea")
      .hasAttribute("placeholder", "Type here");
  });

  test("a control-typed entry (email) maps to the matching input type", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_email=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash key="my_email" type="email" label="My email"}}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_email'] input").hasAttribute("type", "email");
  });

  test("radio-group renders a radio per choice", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_choice="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_choice"
              type="radio-group"
              label="My choice"
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_choice'] input[type='radio'][value='a']")
      .exists();
    assert
      .dom("[data-name='my_choice'] input[type='radio'][value='b']")
      .exists();
    assert.dom("[data-name='my_choice']").containsText("Apple");
  });

  test("placeholder is forwarded to a string control", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_setting=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_setting"
              type="string"
              label="My setting"
              placeholder="Enter a value"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_setting'] input")
      .hasAttribute("placeholder", "Enter a value");
  });

  test("a definition can override the registry entry format", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_setting=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_setting"
              type="string"
              label="My setting"
              format="full"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert.dom("[data-name='my_setting']").hasClass("--full");
  });

  test("enum keeps a stored value that is no longer one of the choices", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum="retired"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_enum'] select option[value='retired']")
      .exists("the stored value is offered as its own option");
    assert
      .dom("[data-name='my_enum'] select")
      .hasValue(
        "retired",
        "a native select would otherwise silently fall back to the first option"
      );
  });

  test("enum does not invent an option for a blank value", async function (assert) {
    await render(
      <template>
        <Form @data={{hash my_enum=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_enum"
              type="enum"
              label="My enum"
              allows_none=true
              valid_values=(array
                (hash value="a" name="Apple") (hash value="b" name="Banana")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_enum'] select option")
      .exists({ count: 3 }, "none plus the two real choices");
  });

  test("locale_enum labels each option with its language name", async function (assert) {
    this.siteSettings.available_locales = [
      { value: "en", name: "English (US)" },
      { value: "fr", name: "French (Français)" },
    ];

    await render(
      <template>
        <Form @data={{hash default_locale="fr"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="default_locale"
              type="locale_enum"
              label="Default locale"
              valid_values=(array
                (hash value="en" name="languages.en.name")
                (hash value="fr" name="languages.fr.name")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='default_locale'] select option[value='fr']")
      .hasText(
        "French (Français)",
        "the localized name is composed with the native name"
      );
    assert.form().field("default_locale").hasValue("fr");
  });
  test("tag_list round-trips names with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_tags="dog|cat"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash key="my_tags" type="tag_list" label="My tags"}}
            @form={{form}}
          />
          <span class="value-probe">{{data.my_tags}}</span>
        </Form>
      </template>
    );

    const control = "[data-name='my_tags'] .d-select";
    assert.dom(control).hasAttribute("data-name", "dog,cat");

    await dSelect(control).selectByName("monkey");

    assert.dom(".value-probe").hasText("dog|cat|monkey");
  });

  test("group_list holds, locks and offers groups with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
      { id: 3, name: "Muffins" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="1|3"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
              disallowed_groups="0"
              mandatory_values="1|2"
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_groups}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_groups'] .d-select";
    assert.dom(control).hasAttribute("data-name", "Donuts,Muffins");
    assert
      .dom(`${control} .d-select__chip[data-value='1']`)
      .hasClass("--locked", "a mandatory group can't be removed");
    assert
      .dom(`${control} .d-select__chip[data-value='3']`)
      .doesNotHaveClass("--locked", "the other groups can");

    await dSelect(control).open();
    assert
      .dom("[role='option'][data-value='0']")
      .doesNotExist("a disallowed group is not offered");

    await dSelect(control).select(2);
    assert.dom(".value-probe").hasAttribute("data-value", "1|3|2");
  });

  test("group_list keeps everyone stored as everyone with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.granular_anonymous_and_logged_in_groups_permissions = true;
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 5, name: "logged_in_users" },
      { id: 11, name: "trust_level_1" },
    ];

    await render(
      <template>
        <Form @data={{hash my_groups="0|11"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_groups"
              type="group_list"
              label="My groups"
              currentSavedValue="0|11"
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_groups}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_groups'] .d-select";
    assert
      .dom(control)
      .hasAttribute(
        "data-name",
        "logged_in_users,trust_level_1",
        "shows logged_in_users in place of everyone"
      );
    assert
      .dom(".value-probe")
      .hasAttribute("data-value", "0|11", "rendering leaves the value alone");

    await dSelect(control).open();
    assert
      .dom("[role='option'][data-value='0']")
      .doesNotExist("everyone is not offered beside logged_in_users");

    await dSelect(control).select(1);
    assert
      .dom(".value-probe")
      .hasAttribute("data-value", "0|11|1", "stores everyone back as everyone");
  });

  test("group picks and clears a group with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const typeOf = (value) => typeof value;
    this.site.groups = [
      { id: 0, name: "everyone" },
      { id: 1, name: "Donuts" },
      { id: 2, name: "Cheese cake" },
    ];

    await render(
      <template>
        <Form @data={{hash my_group="1"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_group"
              type="group"
              label="My group"
              disallowed_groups="2"
            }}
            @form={{form}}
          />
          <span
            class="value-probe"
            data-type={{typeOf data.my_group}}
            data-value={{data.my_group}}
          ></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_group'] .d-select";
    assert.dom(control).hasAttribute("data-name", "Donuts");

    await dSelect(control).open();
    assert
      .dom("[role='option'][data-value='2']")
      .doesNotExist("a disallowed group is not offered");
    assert
      .dom("[role='option'][data-value='0']")
      .hasAttribute("data-name", "everyone (legacy)", "everyone is marked");

    await dSelect(control).select(0);
    assert
      .dom(".value-probe")
      .hasAttribute("data-value", "0", "stores the picked id")
      .hasAttribute(
        "data-type",
        "string",
        "as a string, as the setting holds it"
      );

    await dSelect(control).clear();
    assert
      .dom(".value-probe")
      .hasAttribute(
        "data-value",
        "",
        "a cleared setting holds an empty string"
      );
  });

  test("host_list prompts for a host while it holds none, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_hosts=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_hosts"
              type="host_list"
              label="My hosts"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_hosts'] .d-select__input")
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.host_list.placeholder"),
        "the empty field asks for a host"
      );

    await dSelect("[data-name='my_hosts'] .d-select").open();
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.host_list.empty"),
        "the open list says it holds no hosts, without repeating the prompt"
      );

    await dSelect("[data-name='my_hosts'] .d-select").search("*.x.com");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.host_list.not_allowed"),
        "a refused host says why"
      );
  });

  test("host_list adds typed hosts and refuses wildcards with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_hosts="a.com|b.com"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_hosts"
              type="host_list"
              label="My hosts"
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_hosts}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_hosts'] .d-select";
    assert
      .dom(control)
      .hasAttribute("data-name", "a.com,b.com", "shows each held host");
    assert
      .dom(`${control} .d-select__input`)
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.host_list.add_more_placeholder"),
        "a field holding hosts asks for another"
      );

    await dSelect(control).search("c.com");
    await click("[role='option'].--create");
    assert.dom(".value-probe").hasAttribute("data-value", "a.com|b.com|c.com");

    await dSelect(control).search("*.d.com");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a wildcard host can't be added");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.host_list.not_allowed"),
        "says why instead of reporting no results"
      );

    await dSelect(control).search("e.com|f.com");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a typed separator can't be added");

    await dSelect(control).close();
    await dSelect(control).open();
    assert
      .dom("[role='option'][data-value='a.com']")
      .hasAttribute("aria-selected", "true", "the held hosts are listed");

    await click("[role='option'][data-value='b.com']");
    assert.dom(".value-probe").hasAttribute("data-value", "a.com|c.com");
    assert
      .dom("[role='option'][data-value='b.com']")
      .hasAttribute(
        "aria-selected",
        "false",
        "a removed host stays in the list, unticked"
      );
    await dSelect(control).close();

    await paste(`${control} [role='combobox']`, "x.com|*.y.com");
    assert
      .dom(".value-probe")
      .hasAttribute(
        "data-value",
        "a.com|c.com|x.com",
        "a pasted list adds its hosts and skips the wildcard"
      );
  });

  test("compact_list offers its choices, takes typed entries and keeps removed ones with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_list="a"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "a" "b")
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_list}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_list'] .d-select";
    assert.dom(control).hasAttribute("data-name", "a");
    assert
      .dom(`${control} .d-select__input`)
      .hasAttribute(
        "placeholder",
        i18n("d_select.add_placeholder"),
        "a list with choices keeps the default prompt"
      );

    await dSelect(control).open();
    assert.dom("[role='option'][data-value='b']").exists("offers the choices");
    assert
      .dom("[role='option'][data-value='a']")
      .hasAttribute("aria-selected", "true", "and lists the held values");

    await dSelect(control).search("custom");
    await click("[role='option'].--create");
    assert.dom(".value-probe").hasAttribute("data-value", "a|custom");

    await dSelect(control).search("x|y");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("a typed separator can't be added");

    await dSelect(control).close();
    await dSelect(control).remove("custom");
    assert.dom(".value-probe").hasAttribute("data-value", "a");

    await dSelect(control).open();
    assert
      .dom("[role='option'][data-value='custom']")
      .exists("a removed entry stays on offer");
  });

  test("compact_list and host_list keep a row in place when it is unticked, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form
          @data={{hash my_list="a|b|c" my_hosts="a.com|b.com|c.com"}}
          as |form|
        >
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
            }}
            @form={{form}}
          />
          <SettingDefinitionField
            @definition={{hash
              key="my_hosts"
              type="host_list"
              label="My hosts"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const rowValues = () =>
      [...document.querySelectorAll("[role='option']")].map(
        (row) => row.dataset.value
      );

    await dSelect("[data-name='my_list'] .d-select").open();
    await click("[role='option'][data-value='b']");
    assert.deepEqual(rowValues(), ["a", "b", "c"], "the value keeps its row");
    await dSelect("[data-name='my_list'] .d-select").close();

    await dSelect("[data-name='my_hosts'] .d-select").open();
    await click("[role='option'][data-value='b.com']");
    assert.deepEqual(
      rowValues(),
      ["a.com", "b.com", "c.com"],
      "the host keeps its row"
    );
  });

  test("compact_list refuses typed entries when allow_any is false, with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_list="a"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "a" "b")
              allow_any=false
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    await dSelect("[data-name='my_list'] .d-select").search("custom");
    assert
      .dom("[role='option'].--create")
      .doesNotExist("no typed entry is offered");
  });

  test("compact_list locks held mandatory values with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_list="admin|moderator"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              choices=(array "admin" "moderator")
              mandatory_values="admin|system"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const control = "[data-name='my_list'] .d-select";
    assert
      .dom(`${control} .d-select__chip[data-value='admin']`)
      .hasClass("--locked", "a mandatory value can't be removed");
    assert
      .dom(`${control} .d-select__chip[data-value='moderator']`)
      .doesNotHaveClass("--locked", "the others can");
  });

  test("compact_list without choices prompts for values with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_list=""}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_list}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_list'] .d-select";
    assert
      .dom(`${control} .d-select__input`)
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.compact_list.placeholder"),
        "the empty field asks for a value"
      );

    await dSelect(control).open();
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.compact_list.empty"),
        "the open list says it holds no values, without repeating the prompt"
      );
    await dSelect(control).close();

    await dSelect(control).search("one");
    await click("[role='option'].--create");
    assert.dom(".value-probe").hasAttribute("data-value", "one");
    assert
      .dom(`${control} .d-select__input`)
      .hasAttribute(
        "placeholder",
        i18n("admin.site_settings.compact_list.add_more_placeholder"),
        "a field holding values asks for another"
      );

    await dSelect(control).search("x|y");
    assert
      .dom(".d-select__empty")
      .hasText(
        i18n("admin.site_settings.compact_list.not_allowed"),
        "says why instead of reporting no results"
      );
  });

  test("compact_list shows the names of enum values with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_list="1"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
              allow_any=false
              valid_values=(array
                (hash name="Claude" value=1) (hash name="Other model" value=2)
              )
            }}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_list}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_list'] .d-select";
    assert.dom(control).hasAttribute("data-name", "Claude");

    await dSelect(control).select("2");
    assert.dom(".value-probe").hasAttribute("data-value", "1|2");
  });

  test("compact_list draws a colour square for a colour list with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_colors="f00|nope|0f0" my_list="f00"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_colors"
              type="compact_list"
              label="My colors"
            }}
            @form={{form}}
          />
          <SettingDefinitionField
            @definition={{hash
              key="my_list"
              type="compact_list"
              label="My list"
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    const colors = "[data-name='my_colors'] .d-select";
    assert
      .dom(
        `${colors} .d-select__chip[data-value='f00'] .select-string-list__swatch`
      )
      .hasAttribute("style", /#f00/, "a held colour shows its square");
    assert
      .dom(
        `${colors} .d-select__chip[data-value='nope'] .select-string-list__swatch`
      )
      .doesNotExist("a value that isn't a colour shows none");
    assert
      .dom("[data-name='my_list'] .select-string-list__swatch")
      .doesNotExist("a list that isn't about colours shows none");

    await dSelect(colors).remove("0f0");
    await dSelect(colors).open();
    assert
      .dom("[role='option'][data-value='0f0'] .select-string-list__swatch")
      .hasAttribute("style", /#0f0/, "a listed colour shows its square too");
  });

  test("locale_list shows language names with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.available_locales = [
      { name: "French (Français)", value: "fr" },
      { name: "German (Deutsch)", value: "de" },
    ];

    await render(
      <template>
        <Form @data={{hash my_locales="fr"}} as |form|>
          <SettingDefinitionField
            @definition={{hash
              key="my_locales"
              type="locale_list"
              label="My locales"
              allow_any=false
              valid_values=(array
                (hash name="fr" value="fr") (hash name="de" value="de")
              )
            }}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_locales'] .d-select")
      .hasAttribute("data-name", "French (Français)");
  });

  for (const type of [
    "group",
    "group_list",
    "host_list",
    "compact_list",
    "locale_list",
  ]) {
    test(`${type} is disabled with its field under the new select controls`, async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      const definition = { key: "my_setting", type, label: "My setting" };

      await render(
        <template>
          <Form @data={{hash my_setting=""}} as |form|>
            <SettingDefinitionField
              @definition={{definition}}
              @disabled={{true}}
              @form={{form}}
            />
          </Form>
        </template>
      );

      assert
        .dom("[data-name='my_setting'] .d-select__input")
        .isDisabled("the picker follows its field");
    });
  }

  test("topic picks and clears with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const topics = [
      { id: 5, title: "Cats are fine", fancy_title: "Cats are fine" },
      { id: 8, title: "Birds are loud", fancy_title: "Birds are loud" },
    ];
    pretender.get("/topics/lookup.json", () =>
      response({ topics: topics.filter((topic) => topic.id === 8) })
    );
    pretender.get("/search/query", () =>
      response({
        topics: [topics[0]],
        posts: [{ id: 50, topic_id: 5 }],
      })
    );

    await render(
      <template>
        <Form @data={{hash my_topic="8"}} as |form data|>
          <SettingDefinitionField
            @definition={{hash key="my_topic" type="topic" label="My topic"}}
            @form={{form}}
          />
          <span class="value-probe" data-value={{data.my_topic}}></span>
        </Form>
      </template>
    );

    const control = "[data-name='my_topic'] .d-select";
    await waitFor(`${control}[data-name='Birds are loud']`);
    assert.dom(control).hasAttribute("data-name", "Birds are loud");

    await dSelect(control).search("cats");
    await dSelect(control).select(5);
    assert.dom(".value-probe").hasAttribute("data-value", "5");

    await dSelect(control).clear();
    assert
      .dom(".value-probe")
      .hasAttribute(
        "data-value",
        "",
        "a cleared setting holds an empty string"
      );
  });

  test("topic is disabled with its field under the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;

    await render(
      <template>
        <Form @data={{hash my_topic=""}} as |form|>
          <SettingDefinitionField
            @definition={{hash key="my_topic" type="topic" label="My topic"}}
            @disabled={{true}}
            @form={{form}}
          />
        </Form>
      </template>
    );

    assert
      .dom("[data-name='my_topic'] .d-select__input")
      .isDisabled("the picker follows its field");
  });
});
