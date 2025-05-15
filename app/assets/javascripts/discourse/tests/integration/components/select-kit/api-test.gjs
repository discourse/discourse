import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit, {
  DEFAULT_CONTENT,
  setDefaultState,
} from "discourse/tests/helpers/select-kit-helper";
import ComboBox from "select-kit/components/combo-box";
import SingleSelect from "select-kit/components/single-select";
import { clearCallbacks } from "select-kit/lib/plugin-api";

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
    const self = this;

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

    await render(
      <template>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
      </template>
    );
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 4);

    const appendedRow = this.comboBox.rowByIndex(3);
    assert.true(appendedRow.exists());
    assert.strictEqual(appendedRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.false(this.singleSelect.rowByValue("alpaca").exists());
  });

  test("modifySelectKit(identifier).prependContent", async function (assert) {
    const self = this;

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

    await render(
      <template>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
      </template>
    );
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 4);

    const prependedRow = this.comboBox.rowByIndex(0);
    assert.true(prependedRow.exists());
    assert.strictEqual(prependedRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.false(this.singleSelect.rowByValue("alpaca").exists());
  });

  test("modifySelectKit(identifier).onChange", async function (assert) {
    const self = this;

    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", (api) => {
      api.modifySelectKit("combo-box").onChange((component, value, item) => {
        document.querySelector("#test").innerText = item.name;
      });
    });

    await render(
      <template>
        <div id="test"></div>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
      </template>
    );
    await this.comboBox.expand();
    await this.comboBox.selectRowByIndex(0);

    assert.dom("#test").hasText("foo");
  });

  test("modifySelectKit(identifier).replaceContent", async function (assert) {
    const self = this;

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

    await render(
      <template>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
        />
      </template>
    );
    await this.comboBox.expand();

    assert.strictEqual(this.comboBox.rows().length, 1);

    const replacementRow = this.comboBox.rowByIndex(0);
    assert.true(replacementRow.exists());
    assert.strictEqual(replacementRow.value(), "alpaca");

    await this.comboBox.collapse();

    assert.false(this.singleSelect.rowByValue("alpaca").exists());
  });
});
