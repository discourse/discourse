import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import RagUploadProgress from "discourse/plugins/discourse-ai/discourse/components/rag-upload-progress";

module("Integration | Component | RagUploadProgress", function (hooks) {
  setupRenderingTest(hooks);

  test("keeps other subscribers to the upload when torn down", async function (assert) {
    const upload = { id: 1 };
    const showFirst = tracked(true);

    await render(
      <template>
        <table>
          <tbody>
            {{#if showFirst.value}}
              <tr class="first"><RagUploadProgress @upload={{upload}} /></tr>
            {{/if}}
            <tr class="second"><RagUploadProgress @upload={{upload}} /></tr>
          </tbody>
        </table>
      </template>
    );

    showFirst.value = false;
    await rerender();

    await publishToMessageBus("/discourse-ai/rag/1", {
      total: 2,
      indexed: 1,
      left: 1,
    });

    assert
      .dom(".second .indexing")
      .includesText("50%", "keeps updating the other one");
  });
});
