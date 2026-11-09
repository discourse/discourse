import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ChatToTopicSelector, {
  NEW_MESSAGE_SELECTION,
} from "discourse/plugins/chat/discourse/components/chat-to-topic-selector";

module("Component | ChatToTopicSelector", function (hooks) {
  setupRenderingTest(hooks);

  test("tags picked for a new message reach the caller's tags", async function (assert) {
    getOwner(this).lookup("service:site").can_tag_pms = true;
    const tags = tracked([]);

    await render(
      <template>
        <ChatToTopicSelector
          @allowNewMessage={{true}}
          @instructionLabels={{hash}}
          @selection={{NEW_MESSAGE_SELECTION}}
          @tags={{tags.value}}
        />
      </template>
    );

    assert.dom("#split-message-title").exists("renders the new message form");

    const tagChooser = selectKit(".chat-to-topic-selector .tag-chooser");
    await tagChooser.expand();
    await tagChooser.fillInFilter("mon");
    await tagChooser.selectRowByName("monkey");

    assert.deepEqual(
      (tags.value ?? []).map((tag) =>
        typeof tag === "string" ? tag : tag.name
      ),
      ["monkey"],
      "the caller holds the picked tag"
    );
  });
});
