import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | TopicMap | PrivateMessageMap",
  function (hooks) {
    setupRenderingTest(hooks);

    test("removing a group recipient updates the map without reloading", async function (assert) {
      const topic = this.owner
        .lookup("service:store")
        .createRecord("topic", { id: 123 });
      const details = topic.details;
      details.updateFromJson({
        allowed_groups: [
          { id: 41, name: "first-group" },
          { id: 42, name: "second-group" },
        ],
        allowed_users: [],
        can_remove_allowed_users: true,
      });
      const removeAllowedGroup = (group) => details.removeAllowedGroup(group);
      pretender.put("/t/123/remove-allowed-group", () =>
        response({ success: "OK" })
      );

      await render(
        <template>
          <PrivateMessageMap
            @removeAllowedGroup={{removeAllowedGroup}}
            @topicDetails={{details}}
          />
        </template>
      );

      assert.dom(".group").exists({ count: 2 }, "both groups are rendered");

      await click('.group[data-id="41"] .remove-invited');

      assert
        .dom('.group[data-id="41"]')
        .doesNotExist("the removed group disappears immediately");
      assert.dom('.group[data-id="42"]').exists("other groups are retained");
    });
  }
);
