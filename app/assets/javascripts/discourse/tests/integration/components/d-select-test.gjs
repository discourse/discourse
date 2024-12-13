import { render, select } from "@ember/test-helpers";
import { module, test } from "qunit";
import DSelect, { NO_VALUE_OPTION } from "discourse/components/d-select";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | d-select", function (hooks) {
  setupRenderingTest(hooks);

  test("@onChange", async function (assert) {
    const handleChange = (value) => {
      assert.step(value);
    };

    await render(<template>
      <DSelect @onChange={{handleChange}} as |s|>
        <s.Option @value="foo">The real foo</s.Option>
      </DSelect>
    </template>);

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
    await render(<template>
      <DSelect @value="foo" as |s|>
        <s.Option @value="foo">The real foo</s.Option>
      </DSelect>
    </template>);

    assert.dselect().hasOption({
      value: NO_VALUE_OPTION,
      label: i18n("none_placeholder"),
    });

    assert.dselect().hasSelectedOption({
      value: "foo",
      label: "The real foo",
    });
  });

  test("select attributes", async function (assert) {
    await render(<template><DSelect class="test" /></template>);

    assert.dom(".d-select.test").exists();
  });

  test("option attributes", async function (assert) {
    await render(<template>
      <DSelect as |s|>
        <s.Option @value="foo" class="test">The real foo</s.Option>
      </DSelect>
    </template>);

    assert.dom(".d-select__option.test").exists();
  });
});
