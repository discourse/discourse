import { hash } from "@ember/helper";
import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import SearchMenu, {
  DEFAULT_TYPE_FILTER,
} from "discourse/components/search-menu";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKitHelper from "discourse/tests/helpers/form-kit-helper";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

// Note this isn't a full-fledge test of the search menu. Those tests are in
// acceptance/search-test.js. This is simply about the rendering of the
// menu panel separate from the search input.
module("Integration | Component | something", function (hooks) {
  setupRenderingTest(hooks);

  test("what is going on", async function (assert) {
    await render(<template>
      <Form @data={{hash foo="test"}} class="my-form" as |form data|>
        {{data.foo}}
        <form.Field @name="foo" as |field|>
          <field.Input />
        </form.Field>

        {{data.checkbox_1}}
        <form.Field @name="checkbox_1" as |field|>
          <field.Checkbox />
        </form.Field>

        {{data.select_1}}
        <form.Field @name="select_1" as |field|>
          <field.Select as |select|>
            <select.Option @value="1">One</select.Option>
            <select.Option @value="2">Two</select.Option>
          </field.Select>
        </form.Field>

        {{data.radioGroup}}
        <form.Field @name="radioGroup" as |field|>
          <field.RadioGroup
            @title="Foo"
            @subtitle="Bar"
            @description="baz"
            as |radioGroup|
          >
            <radioGroup.Radio @value="1">One</radioGroup.Radio>
            <radioGroup.Radio @value="2">Two</radioGroup.Radio>
          </field.RadioGroup>
        </form.Field>

        {{data.menu}}
        <form.Field @name="menu" as |field|>
          <field.Menu as |menu|>
            <menu.Item @value="1">One</menu.Item>
            <menu.Item @value="2">Two</menu.Item>
          </field.Menu>
        </form.Field>

        {{data.code}}
        <form.Field @name="code" as |field|>
          <field.Code />
        </form.Field>

        {{!-- {{data.icon}}
        <form.Field @name="icon" as |field|>
          <field.Icon />
        </form.Field> --}}

        <form.Field @name="icon" as |field|>
          <field.Image />
        </form.Field>
      </Form>
    </template>);

    const myForm = formKitHelper(".my-form");
    assert.form(".my-form").field("foo").hasValue("test");

    await myForm.field("foo").fillIn("jojo");

    assert.form(".my-form").field("foo").hasValue("jojo");
    console.log(myForm.field("checkbox_1"));

    await myForm.field("checkbox_1").toggle();

    await myForm.field("select_1").select(2);
    // await myForm.field("select_1").selectIndex(1);

    await myForm.field("radioGroup").select(2);
    await myForm.field("menu").select(2);
    await myForm.field("code").fillIn("test");
    await myForm.field("icon").select("pencil-alt");
    await pauseTest();

    // assert.form(query(".my-form")).field("foo").isDisabled("test");
  });
});
