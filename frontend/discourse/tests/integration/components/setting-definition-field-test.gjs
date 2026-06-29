import { array, hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
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

    const groups = selectKit("[data-name='my_groups'] .group-chooser");
    assert.strictEqual(
      groups.header().value(),
      "1",
      "deserializes the pipe string into the selected group"
    );

    await groups.expand();
    await groups.selectRowByValue(2);

    assert
      .dom(".value-probe")
      .hasText("1|2", "serializes the selection back to a pipe string");
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
});
