import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-chrome";
import { queryOf } from "../../../helpers/wireframe-peers";

// A bare stand-in — the prompt is painted by the chrome from the block's
// metadata, not by the wrapped component.
const WrappedTopicCard = <template>
  <div class="d-block-topic-card"></div>
</template>;

module(
  "Integration | discourse-wireframe | empty-arg prompt",
  function (hooks) {
    setupRenderingTest(hooks);

    test("prompts to configure an unset identifying arg and selects on click", async function (assert) {
      const selection = this.owner.lookup("service:wireframe-selection");
      const blockKey = "topic-card:test";

      this.owner.lookup("service:wireframe-edit-mode").activate();
      // topic-card's `topicId` is unset, so the chrome should surface its
      // `ui.emptyPrompt` over the block.
      queryOf(this).findEntryAndOutletSync = () => ({
        entry: { args: {} },
        outletName: "test-outlet",
      });

      await render(
        <template>
          <BlockChrome
            @blockName="topic-card"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedTopicCard}}
          />
        </template>
      );

      assert
        .dom(".wireframe-empty-arg-prompt")
        .exists("paints the prompt over the unconfigured block")
        .hasText(
          i18n("blocks.builtin.topic_card.empty_prompt"),
          "shows the arg's editor prompt copy"
        );

      await click(".wireframe-empty-arg-prompt");

      assert.strictEqual(
        selection.selectedBlockKey,
        blockKey,
        "activating the prompt selects the block so its inspector opens"
      );
    });

    test("shows no prompt once the identifying arg is set", async function (assert) {
      const blockKey = "topic-card:test";

      this.owner.lookup("service:wireframe-edit-mode").activate();
      queryOf(this).findEntryAndOutletSync = () => ({
        entry: { args: { topicId: 42 } },
        outletName: "test-outlet",
      });

      await render(
        <template>
          <BlockChrome
            @blockName="topic-card"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedTopicCard}}
          />
        </template>
      );

      assert
        .dom(".wireframe-empty-arg-prompt")
        .doesNotExist("a configured block gets no prompt");
    });
  }
);
