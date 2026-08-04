import { tracked } from "@glimmer/tracking";
import { render, select, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect, { NO_VALUE_OPTION } from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DSelect", function (hooks) {
  setupRenderingTest(hooks);

  test("@onChange", async function (assert) {
    const handleChange = (value) => {
      assert.step(value);
    };

    await render(
      <template>
        <DSelect @onChange={{handleChange}} as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DSelect>
      </template>
    );

    await select(".d-select", "foo");

    assert.verifySteps(["foo"]);
  });

  test("no value", async function (assert) {
    await render(<template><DSelect /></template>);

    assert.dselect().hasSelectedOption({
      value: NO_VALUE_OPTION,
      label: i18n("select_placeholder"),
    });
  });

  test("selected value", async function (assert) {
    await render(
      <template>
        <DSelect @value="foo" as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DSelect>
      </template>
    );

    assert.dselect().hasOption({
      value: NO_VALUE_OPTION,
      label: i18n("none_placeholder"),
    });

    assert.dselect().hasSelectedOption({
      value: "foo",
      label: "The real foo",
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
        <DSelect @value="bar" as |s|>
          {{#each state.options as |option|}}
            <s.Option @value={{option.value}}>{{option.label}}</s.Option>
          {{/each}}
        </DSelect>
      </template>
    );

    assert.dselect().hasSelectedOption({
      value: "bar",
      label: "The real bar",
    });

    state.options = [
      { value: "baz", label: "The real baz" },
      { value: "foo", label: "The real foo" },
      { value: "bar", label: "The real bar" },
    ];
    await settled();

    assert.dselect().hasSelectedOption({
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
        <DSelect
          @includeNone={{false}}
          @value={{state.value}}
          @onChange={{handleChange}}
          as |s|
        >
          <s.Option @value={{1}}>One</s.Option>
          <s.Option @value={{30}}>Thirty</s.Option>
          <s.Option @value={{90}}>Ninety</s.Option>
        </DSelect>
      </template>
    );

    await select(".d-select", "90");

    assert.dselect().hasSelectedOption({ value: "90", label: "Ninety" });
  });

  test("required field", async function (assert) {
    await render(
      <template>
        <DSelect @includeNone={{false}} as |s|>
          <s.Option @value="foo">The real foo</s.Option>
        </DSelect>
      </template>
    );

    assert.dselect().hasNoOption(NO_VALUE_OPTION);
  });

  test("select attributes", async function (assert) {
    await render(<template><DSelect class="test" /></template>);

    assert.dom(".d-select.test").exists();
  });

  test("option attributes", async function (assert) {
    await render(
      <template>
        <DSelect as |s|>
          <s.Option @value="foo" class="test">The real foo</s.Option>
        </DSelect>
      </template>
    );

    assert.dom(".d-select__option.test").exists();
  });
});
