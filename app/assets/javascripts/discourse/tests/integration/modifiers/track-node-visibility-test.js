import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Modifier | track-node-visibility", function (hooks) {
  setupRenderingTest(hooks);

  test("didEnterViewport", async function (assert) {
    const done = assert.async();

    this.didEnterViewPort = () => {
      assert.step("didEnterViewport");
      assert.verifySteps(["didLeaveViewport", "didEnterViewport"]);
      done();
    };
    this.didLeaveViewport = () => assert.step("didLeaveViewport");

    await render(hbs`
      <div class="tracker" style="display: none" {{track-node-visibility this.didEnterViewPort this.didLeaveViewport}}>
        test
      </div>
     `);

    document.querySelector(".tracker").style.display = "block";
  });

  test("didLeaveViewport", async function (assert) {
    const done = assert.async();

    this.didEnterViewPort = () => assert.step("didEnterViewport");
    this.didLeaveViewport = () => {
      assert.step("didLeaveViewport");
      assert.verifySteps(["didEnterViewport", "didLeaveViewport"]);
      done();
    };

    await render(hbs`
      <div class="tracker" {{track-node-visibility this.didEnterViewPort this.didLeaveViewport}}>
        test
      </div>
     `);

    document.querySelector(".tracker").style.display = "none";
  });
});
