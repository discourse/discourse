import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import PrivateMessageMap from "discourse/components/topic-map/private-message-map";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | TopicMap | PrivateMessageMap",
  function (hooks) {
    setupRenderingTest(hooks);

    test("group recipients remain reactive after hydration and removal", async function (assert) {
      const topic = this.owner
        .lookup("service:store")
        .createRecord("topic", { id: 123 });
      const details = topic.details;
      details.updateFromJson({
        allowed_groups: [{ id: 41, name: "first-group" }],
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

      assert
        .dom('.group[data-id="41"]')
        .exists("the initial group is rendered");

      details.allowed_groups.push({ id: 42, name: "second-group" });
      await settled();

      assert
        .dom('.group[data-id="42"]')
        .exists("mutating the hydrated group list updates the map");

      await click('.group[data-id="41"] .remove-invited');

      assert
        .dom('.group[data-id="41"]')
        .doesNotExist("the removed group disappears immediately");
      assert.dom('.group[data-id="42"]').exists("other groups are retained");

      details.allowed_groups.push({ id: 43, name: "third-group" });
      await settled();

      assert
        .dom('.group[data-id="43"]')
        .exists("the group list still tracks mutations after removal");
    });
  }
);
