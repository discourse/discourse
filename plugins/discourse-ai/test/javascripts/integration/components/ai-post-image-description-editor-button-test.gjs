import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiPostImageDescriptionEditorButton from "discourse/plugins/discourse-ai/discourse/components/ai-post-image-description-editor-button";

class PostImageDescriptionEditorStub extends Service {
  openedBase62Sha1 = null;

  descriptionFor(base62Sha1) {
    if (base62Sha1 === "abc123") {
      return "A stored description";
    }
  }
}

class ModalStub extends Service {
  show(_modal, options) {
    this.model = options.model;
  }
}

module(
  "Integration | Component | AiPostImageDescriptionEditorButton",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.unregister("service:post-image-description-editor");
      this.owner.unregister("service:modal");
      this.owner.register(
        "service:post-image-description-editor",
        PostImageDescriptionEditorStub
      );
      this.owner.register("service:modal", ModalStub);
    });

    test("renders when the image has an editable description", async function (assert) {
      await render(
        <template>
          <AiPostImageDescriptionEditorButton @base62Sha1="abc123" />
        </template>
      );

      assert
        .dom(".ai-post-image-description-editor__button")
        .exists("the edit button is shown");
    });

    test("opens the editor modal for the image", async function (assert) {
      await render(
        <template>
          <AiPostImageDescriptionEditorButton @base62Sha1="abc123" />
        </template>
      );

      await click(".ai-post-image-description-editor__button");

      const modal = this.owner.lookup("service:modal");
      assert.deepEqual(modal.model, {
        base62Sha1: "abc123",
        description: "A stored description",
      });
    });

    test("does not render without an editable description", async function (assert) {
      await render(
        <template>
          <AiPostImageDescriptionEditorButton @base62Sha1="missing" />
        </template>
      );

      assert
        .dom(".ai-post-image-description-editor__button")
        .doesNotExist("the edit button is hidden");
    });
  }
);
