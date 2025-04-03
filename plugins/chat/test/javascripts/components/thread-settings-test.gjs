import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatModalThreadSettings from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | <ThreadSettings />", function (hooks) {
  setupRenderingTest(hooks);

  test("discourse-ai - admin", async function (assert) {
    this.currentUser.admin = true;
    const thread = new ChatFabricators(getOwner(this)).thread();

    await render(
      <template>
        <ChatModalThreadSettings @inline={{true}} @model={{thread}} />
      </template>
    );

    assert.dom(".discourse-ai-cta").exists();
  });

  test("discourse-ai - not admin", async function (assert) {
    this.currentUser.admin = false;
    const thread = new ChatFabricators(getOwner(this)).thread();

    await render(
      <template>
        <ChatModalThreadSettings @inline={{true}} @model={{thread}} />
      </template>
    );

    assert.dom(".discourse-ai-cta").doesNotExist();
  });
});
