import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | prosemirror-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the editor", async function (assert) {
    await render(<template><ProsemirrorEditor /></template>);
    assert.dom(".ProseMirror").exists("it renders the ProseMirror editor");
  });
});
