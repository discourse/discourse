import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Header from "discourse/plugins/chat/discourse/components/chat/thread/header";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-thread-header", function (hooks) {
  setupRenderingTest(hooks);

  test("it safely renders title", async function (assert) {
    const self = this;

    const title = "<style>body { background: red;}</style>";
    this.thread = new ChatFabricators(getOwner(this)).thread({ title });

    await render(
      <template>
        <Header @thread={{self.thread}} @channel={{self.thread.channel}} />
      </template>
    );

    assert
      .dom(".c-navbar__title")
      .includesHtml("&lt;style&gt;body { background: red;}&lt;/style&gt;");
  });
});
