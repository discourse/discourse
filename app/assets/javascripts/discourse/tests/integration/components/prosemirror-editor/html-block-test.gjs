import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ProsemirrorEditor from "discourse/static/prosemirror/components/prosemirror-editor";
import htmlBlock from "discourse/static/prosemirror/extensions/html-block";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Integration | Component | prosemirror-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the html-block", async function (assert) {
    withPluginApi("1.40.0", (api) =>
      api.registerRichEditorExtension(htmlBlock)
    );

    const value = `<div>
block1

# some markdown
</div>
<div>

block2

</div>
<div>

block3
</div>`;

    await render(<template><ProsemirrorEditor @value={{value}} /></template>);

    const editor = document.querySelector(".d-editor__editable");

    assert.dom("div > h1", editor).hasText("some markdown");

    assert.dom("div:nth-of-type(1)", editor).hasTextContaining("block1");

    assert.dom("div:nth-of-type(2)", editor).hasText("block2");

    assert.dom("div:nth-of-type(3)", editor).hasText("block3");
  });
});
