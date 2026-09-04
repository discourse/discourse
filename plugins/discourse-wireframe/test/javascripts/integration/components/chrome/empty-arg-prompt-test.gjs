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

const WrappedEmptySection = <template>
  <section class="d-block-section">
    <div
      class="d-block-section__backdrop"
      data-block-arg="backgroundImage"
      data-drop-passive
    ></div>
    <div
      class="d-block-section__content"
      data-wf-drop-container="true"
      data-wf-empty-host="true"
    ></div>
  </section>
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

    test("renders a section empty state inside its content boundary", async function (assert) {
      const blockKey = "section:test";

      this.owner.lookup("service:wireframe-edit-mode").activate();
      queryOf(this).findEntryAndOutletSync = () => ({
        entry: { block: "section", args: {}, children: [] },
        outletName: "test-outlet",
      });

      await render(
        <template>
          <BlockChrome
            @blockName="section"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedEmptySection}}
          />
        </template>
      );

      assert
        .dom(
          ".d-block-section__content > .wireframe-empty-drop-actions > .wireframe-empty-drop-placeholder"
        )
        .exists("the add-content action uses the section's stable empty host")
        .hasText(i18n("wireframe.canvas.add_content"));
      assert
        .dom(
          ".d-block-section__content .wireframe-empty-drop-actions__background"
        )
        .exists("the same empty state offers a background image action");
      assert
        .dom(".wireframe-block-chrome > .wireframe-empty-drop-placeholder")
        .doesNotExist("no competing full-chrome empty placeholder remains");
    });

    test("keeps an empty section readable over a filled background", async function (assert) {
      const blockKey = "section:test";

      this.owner.lookup("service:wireframe-edit-mode").activate();
      queryOf(this).findEntryAndOutletSync = () => ({
        entry: {
          block: "section",
          args: { backgroundImage: { url: "/images/featured.png" } },
          children: [],
        },
        outletName: "test-outlet",
      });

      await render(
        <template>
          <BlockChrome
            @blockName="section"
            @blockKey={{blockKey}}
            @outletName="test-outlet"
            @WrappedComponent={{WrappedEmptySection}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-chrome")
        .hasClass(
          "--media-background",
          "the chrome marks content rendered over a background image"
        );
      assert
        .dom(
          ".d-block-section__content > .wireframe-empty-drop-actions > .wireframe-empty-drop-placeholder"
        )
        .exists("the readable action surface remains around Add content");
      assert
        .dom(
          ".d-block-section__content .wireframe-empty-drop-actions__background"
        )
        .doesNotExist("a configured background is not offered as an empty arg");
    });
  }
);
