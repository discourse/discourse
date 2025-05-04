import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Item from "discourse/plugins/chat/discourse/components/chat/thread-list/item";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Component | chat-thread-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("it safely renders title", async function (assert) {
    const self = this;

    const title = "<style>body { background: red;}</style>";
    this.thread = new ChatFabricators(getOwner(this)).thread({ title });

    await render(<template><Item @thread={{self.thread}} /></template>);

    assert
      .dom(".chat-thread-list-item__title")
      .hasHtml("&lt;style&gt;body { background: red;}&lt;/style&gt;");
  });
});
