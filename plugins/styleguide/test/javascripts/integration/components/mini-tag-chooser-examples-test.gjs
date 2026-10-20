import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import MiniTagChooserExample from "discourse/plugins/styleguide/discourse/components/examples/atoms/dropdowns/mini-tag-chooser";
import MiniTagChooserHeaderFilterExample from "discourse/plugins/styleguide/discourse/components/examples/atoms/dropdowns/mini-tag-chooser-header-filter";

module(
  "Styleguide | Integration | mini-tag-chooser examples",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the mini tag chooser demo shows a tag picked from its list", async function (assert) {
      await render(<template><MiniTagChooserExample /></template>);

      const chooser = selectKit(".mini-tag-chooser");
      assert.strictEqual(chooser.header().name(), "apple,orange,potato");

      await chooser.expand();
      await chooser.fillInFilter("mon");
      await chooser.selectRowByName("monkey");

      assert.strictEqual(
        chooser.header().name(),
        "apple,orange,potato,monkey",
        "the demo shows the picked tag after the initial ones"
      );
    });

    test("the header filter mini tag chooser demo shows a tag picked from its list", async function (assert) {
      await render(<template><MiniTagChooserHeaderFilterExample /></template>);

      const chooser = selectKit(".mini-tag-chooser");
      assert.strictEqual(chooser.header().name(), "apple,orange,potato");

      await chooser.expand();
      await chooser.fillInFilter("mon");
      await chooser.selectRowByName("monkey");

      assert.strictEqual(
        chooser.header().name(),
        "apple,orange,potato,monkey",
        "the demo shows the picked tag after the initial ones"
      );
    });
  }
);
