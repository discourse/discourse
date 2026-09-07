import { tracked } from "@glimmer/tracking";
import { render, select, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DNativeSelect, {
  NO_VALUE_OPTION,
} from "discourse/ui-kit/d-native-select";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DNativeSelect", function (hooks) {
  setupRenderingTest(hooks);

  test("@onChange", async function (assert) {
    const handleChange = (value) => {
      assert.step(value);
    };

    await render(
      <template>
        <DNativeSelect @onChange={{handleChange}} as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DNativeSelect>
      </template>
    );

    await select(".d-native-select", "foo");

    assert.verifySteps(["foo"]);
  });

  test("@onChange with the none option", async function (assert) {
    let changedValue = "not called";
    const handleChange = (value) => (changedValue = value);

    await render(
      <template>
        <DNativeSelect @value="foo" @onChange={{handleChange}} as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DNativeSelect>
      </template>
    );

    await select(".d-native-select", NO_VALUE_OPTION);

    assert.strictEqual(
      changedValue,
      null,
      "emits null, so the cleared value survives JSON serialization"
    );
  });

  test("no value", async function (assert) {
    await render(<template><DNativeSelect /></template>);

    assert.dnativeselect().hasSelectedOption({
      value: NO_VALUE_OPTION,
      label: i18n("select_placeholder"),
    });
  });

  test("selected value", async function (assert) {
    await render(
      <template>
        <DNativeSelect @value="foo" as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DNativeSelect>
      </template>
    );

    assert.dnativeselect().hasOption({
      value: NO_VALUE_OPTION,
      label: i18n("none_placeholder"),
    });

    assert.dnativeselect().hasSelectedOption({
      value: "foo",
      label: "The real foo",
    });
  });

  test("selected falsy value", async function (assert) {
    await render(
      <template>
        <DNativeSelect @value={{false}} as |s|>
          <s.Option @value={{false}}>The real false</s.Option>
          <s.Option @value={{true}}>The real true</s.Option>
        </DNativeSelect>
      </template>
    );

    assert.dnativeselect().hasOption({
      value: NO_VALUE_OPTION,
      label: i18n("none_placeholder"),
    });

    assert.dnativeselect().hasSelectedOption({
      value: "false",
      label: "The real false",
    });
  });

  test("keeps the selection when options are rebuilt", async function (assert) {
    class State {
      @tracked
      options = [
        { value: "foo", label: "The real foo" },
        { value: "bar", label: "The real bar" },
      ];
    }

    const state = new State();

    await render(
      <template>
        <DNativeSelect @value="bar" as |s|>
          {{#each state.options as |option|}}
            <s.Option @value={{option.value}}>{{option.label}}</s.Option>
          {{/each}}
        </DNativeSelect>
      </template>
    );

    assert.dnativeselect().hasSelectedOption({
      value: "bar",
      label: "The real bar",
    });

    state.options = [
      { value: "baz", label: "The real baz" },
      { value: "foo", label: "The real foo" },
      { value: "bar", label: "The real bar" },
    ];
    await settled();

    assert.dnativeselect().hasSelectedOption({
      value: "bar",
      label: "The real bar",
    });
  });

  test("keeps the selection when the value is not a string", async function (assert) {
    class State {
      @tracked value = 30;
    }

    const state = new State();
    const handleChange = (value) => (state.value = value);

    await render(
      <template>
        <DNativeSelect
          @includeNone={{false}}
          @value={{state.value}}
          @onChange={{handleChange}}
          as |s|
        >
          <s.Option @value={{1}}>One</s.Option>
          <s.Option @value={{30}}>Thirty</s.Option>
          <s.Option @value={{90}}>Ninety</s.Option>
        </DNativeSelect>
      </template>
    );

    await select(".d-native-select", "90");

    assert.dnativeselect().hasSelectedOption({ value: "90", label: "Ninety" });
  });

  test("required field", async function (assert) {
    await render(
      <template>
        <DNativeSelect @includeNone={{false}} as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DNativeSelect>
      </template>
    );

    assert.dnativeselect().hasNoOption(NO_VALUE_OPTION);
  });

  test("select attributes", async function (assert) {
    await render(<template><DNativeSelect class="test" /></template>);

    assert.dom(".d-native-select.test").exists();
  });

  test("option attributes", async function (assert) {
    await render(
      <template>
        <DNativeSelect as |s|>
          <s.Option @value="foo" class="test">The real foo</s.Option>
        </DNativeSelect>
      </template>
    );

    assert.dom(".d-native-select__option.test").exists();
  });
});
