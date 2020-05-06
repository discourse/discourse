import componentTest from "helpers/component-test";
import selectKit, {
  testSelectKitModule,
  setDefaultState,
  DEFAULT_CONTENT
} from "helpers/select-kit-helper";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "select-kit/mixins/plugin-api";

testSelectKitModule("select-kit:api", {
  beforeEach() {
    this.setProperties({
      comboBox: selectKit(".combo-box"),
      singleSelect: selectKit(".single-select:not(.combo-box)")
    });
  },

  afterEach() {
    clearCallbacks();
  }
});

componentTest("modifySelectKit(identifier).appendContent", {
  template: `
    {{combo-box value=value content=content onChange=onChange}}
    {{single-select value=value content=content onChange=onChange}}
  `,

  beforeEach() {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", api => {
      api.modifySelectKit("combo-box").appendContent(() => {
        return {
          id: "alpaca",
          name: "Alpaca"
        };
      });
    });
  },

  async test(assert) {
    await this.comboBox.expand();
    const row = this.comboBox.rowByIndex(3);
    assert.ok(row.exists());
    assert.equal(row.value(), "alpaca");

    await this.comboBox.collapse();

    assert.notOk(this.singleSelect.rowByValue("alpaca").exists());
  }
});

componentTest("modifySelectKit(identifier).prependContent", {
  template: `
    {{combo-box value=value content=content onChange=onChange}}
    {{single-select value=value content=content onChange=onChange}}
  `,

  beforeEach() {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", api => {
      api.modifySelectKit("combo-box").prependContent(() => {
        return {
          id: "alpaca",
          name: "Alpaca"
        };
      });
    });
  },

  afterEach() {},

  async test(assert) {
    await this.comboBox.expand();
    const row = this.comboBox.rowByIndex(0);
    assert.ok(row.exists());
    assert.equal(row.value(), "alpaca");

    await this.comboBox.collapse();

    assert.notOk(this.singleSelect.rowByValue("alpaca").exists());
  }
});

componentTest("modifySelectKit(identifier).onChange", {
  template: `
    <div id="test"></div>
    {{combo-box value=value content=content onChange=onChange}}
  `,

  beforeEach() {
    setDefaultState(this, null, { content: DEFAULT_CONTENT });

    withPluginApi("0.8.43", api => {
      api.modifySelectKit("combo-box").onChange((component, value, item) => {
        find("#test").text(item.name);
      });
    });
  },

  async test(assert) {
    await this.comboBox.expand();
    await this.comboBox.selectRowByIndex(0);

    assert.equal(find("#test").text(), "foo");
  }
});
