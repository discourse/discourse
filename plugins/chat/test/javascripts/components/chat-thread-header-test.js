import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-thread-header", function (hooks) {
  setupRenderingTest(hooks);

  test("it safely renders title", async function (assert) {
    const title = "<style>body { background: red;}</style>";
    this.thread = new ChatFabricators(getOwner(this)).thread({ title });

    await render(hbs`
      <Chat::Thread::Header @thread={{this.thread}} @channel={{this.thread.channel}} />
    `);

    assert
      .dom(".c-navbar__title")
      .includesHtml("&lt;style&gt;body { background: red;}&lt;/style&gt;");
  });
});
