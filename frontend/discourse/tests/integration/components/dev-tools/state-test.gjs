import Component from "@glimmer/component";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import devToolsState from "discourse/static/dev-tools/state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const STORAGE_KEY = "discourse__dev_tools_state";
const TOOL_ID = "reactive-probe-tool";

class FlagProbe extends Component {
  get value() {
    return devToolsState.getFlag(TOOL_ID, "enabled");
  }

  <template>
    <span class="flag-probe">{{this.value}}</span>
  </template>
}

module("Integration | Component | dev-tools | state", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalStorage = window.sessionStorage.getItem(STORAGE_KEY);
    this.originalFlag = devToolsState.getFlag(TOOL_ID, "enabled");
  });

  hooks.afterEach(function () {
    devToolsState.setFlag(TOOL_ID, "enabled", this.originalFlag);

    if (this.originalStorage === null) {
      window.sessionStorage.removeItem(STORAGE_KEY);
    } else {
      window.sessionStorage.setItem(STORAGE_KEY, this.originalStorage);
    }
  });

  test("changing a tool's flag rerenders what reads it", async function (assert) {
    devToolsState.setFlag(TOOL_ID, "enabled", false);

    await render(<template><FlagProbe /></template>);
    assert.dom(".flag-probe").hasText("false", "the initial flag renders");

    devToolsState.setFlag(TOOL_ID, "enabled", true);
    await rerender();

    assert
      .dom(".flag-probe")
      .hasText("true", "changing the flag rerenders its consumer");
  });
});
