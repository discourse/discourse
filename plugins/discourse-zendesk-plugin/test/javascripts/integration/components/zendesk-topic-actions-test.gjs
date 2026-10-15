import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import ZendeskTopicActions from "discourse/plugins/discourse-zendesk-plugin/discourse-zendesk-plugin/connectors/after-topic-footer-buttons/zendesk-topic-actions";

module("Integration | Component | ZendeskTopicActions", function (hooks) {
  setupRenderingTest(hooks);

  test("links to the issue it creates", async function (assert) {
    logIn(getOwner(this));
    updateCurrentUser({ staff: true, discourse_zendesk_plugin_status: true });
    pretender.post("/zendesk-plugin/issues", () =>
      response({
        discourse_zendesk_plugin_zendesk_id: "42",
        discourse_zendesk_plugin_zendesk_url: "https://zendesk.example/42",
      })
    );
    const topic = EmberObject.create({ id: 1 });

    await render(<template><ZendeskTopicActions @topic={{topic}} /></template>);
    await click(".zendesk-topic-actions .btn-primary");

    assert
      .dom(".zendesk-topic-actions a.btn-primary")
      .hasAttribute("href", "https://zendesk.example/42", "links the issue");
  });
});
