import { array, concat, hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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

    assert
      .dom("[data-name='my_enum'] select option[value='5']")
      .hasAttribute("selected");
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
});
