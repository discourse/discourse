import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import selectKit, {
  DEFAULT_CONTENT,
  setDefaultState,
} from "discourse/tests/helpers/select-kit-helper";
import { clearCallbacks } from "select-kit/mixins/plugin-api";

module("Integration | Component | select-kit/api", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.setProperties({
      comboBox: selectKit(".combo-box"),
      singleSelect: selectKit(".single-select:not(.combo-box)"),
    });
  });

  hooks.afterEach(function () {
    clearCallbacks();
  });

  test("modifySelectKit(identifier).appendContent", async function (assert) {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", (api) => {
      api.modifySelectKit("combo-box").appendContent(() => {
        return {
          id: "alpaca",
          name: "Alpaca",
        };
      });
      api.modifySelectKit("combo-box").appendContent(() => {});
    });

    await render(hbs`
      <ComboBox @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
      <SingleSelect @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
    `);
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 4);

    const appendedRow = this.comboBox.rowByIndex(3);
    assert.ok(appendedRow.exists());
    assert.strictEqual(appendedRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.notOk(this.singleSelect.rowByValue("alpaca").exists());
  });

  test("modifySelectKit(identifier).prependContent", async function (assert) {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", (api) => {
      api.modifySelectKit("combo-box").prependContent(() => {
        return {
          id: "alpaca",
          name: "Alpaca",
        };
      });
      api.modifySelectKit("combo-box").prependContent(() => {});
    });

    await render(hbs`
      <ComboBox @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
      <SingleSelect @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
    `);
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 4);

    const prependedRow = this.comboBox.rowByIndex(0);
    assert.ok(prependedRow.exists());
    assert.strictEqual(prependedRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.notOk(this.singleSelect.rowByValue("alpaca").exists());
  });

  test("modifySelectKit(identifier).onChange", async function (assert) {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", (api) => {
      api.modifySelectKit("combo-box").onChange((component, value, item) => {
        query("#test").innerText = item.name;
      });
    });

    await render(hbs`
      <div id="test"></div>
      <ComboBox @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
    `);
    await this.comboBox.expand();
    await this.comboBox.selectRowByIndex(0);

    assert.dom("#test").hasText("foo");
  });

  test("modifySelectKit(identifier).replaceContent", async function (assert) {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", (api) => {
      api.modifySelectKit("combo-box").replaceContent(() => {
        return {
          id: "alpaca",
          name: "Alpaca",
        };
      });
      api.modifySelectKit("combo-box").replaceContent(() => {});
    });

    await render(hbs`
      <ComboBox @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
      <SingleSelect @value={{this.value}} @content={{this.content}} @onChange={{this.onChange}} />
    `);
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 1);

    const replacementRow = this.comboBox.rowByIndex(0);
    assert.ok(replacementRow.exists());
    assert.strictEqual(replacementRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.notOk(this.singleSelect.rowByValue("alpaca").exists());
  });
});
