import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiToolEditor from "discourse/plugins/discourse-ai/discourse/components/ai-tool-editor";

module("Integration | Component | AiToolEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("passes the RAG settings to the form", async function (assert) {
    this.siteSettings.ai_embeddings_enabled = true;
    const model = { isNew: false };
    const presets = [];
    const settings = { rag_images_enabled: true };

    await render(
      <template>
        <AiToolEditor
          @model={{model}}
          @presets={{presets}}
          @settings={{settings}}
        />
      </template>
    );

    assert
      .dom(".rag-uploader .hidden-upload-field")
      .hasAttribute(
        "accept",
        ".txt,.md,.png,.jpg,.jpeg",
        "accepts images when RAG images are enabled"
      );
  });
});
