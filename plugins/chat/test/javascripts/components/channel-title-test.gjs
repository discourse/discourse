import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | <ChannelTitle />", function (hooks) {
  setupRenderingTest(hooks);

  test("icon", async function (assert) {
    const channel = fabricators.channel();

    await render(<template><ChannelTitle @channel={{channel}} /></template>);

    assert.dom(".chat-channel-icon").exists();
  });

  test("label", async function (assert) {
    const channel = fabricators.channel();

    await render(<template><ChannelTitle @channel={{channel}} /></template>);

    assert.dom(".chat-channel-name").exists();
  });
});
