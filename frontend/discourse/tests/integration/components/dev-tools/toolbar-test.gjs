import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { clearDevTools, devToolsDAG } from "discourse/lib/dev-tools/registry";
import Toolbar from "discourse/static/dev-tools/toolbar";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const First = <template>
  <button type="button" class="first-tool"></button>
</template>;
const Second = <template>
  <button type="button" class="second-tool"></button>
</template>;

module("Integration | Component | dev-tools | toolbar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    clearDevTools();
  });

  test("renders registered tools between the gripper and the disable button", async function (assert) {
    devToolsDAG().add("first", First);
    devToolsDAG().add("second", Second, { after: "first" });

    await render(<template><Toolbar /></template>);

    assert.dom(".dev-tools-toolbar .first-tool").exists();
    assert.dom(".dev-tools-toolbar .second-tool").exists();

    const classes = [
      ...document.querySelectorAll(".dev-tools-toolbar > *"),
    ].map((element) => element.className);

    assert.deepEqual(
      classes,
      ["gripper", "first-tool", "second-tool", "disable-dev-tools"],
      "tools render in registry order, with the chrome around them"
    );
  });

  test("renders only its own chrome when no tools are registered", async function (assert) {
    await render(<template><Toolbar /></template>);

    assert.dom(".dev-tools-toolbar").exists("the toolbar itself still renders");
    assert.dom(".dev-tools-toolbar .gripper").exists();
    assert.dom(".dev-tools-toolbar .disable-dev-tools").exists();
  });
});
