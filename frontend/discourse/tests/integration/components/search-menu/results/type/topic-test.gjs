import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicResultComponent from "discourse/components/search-menu/results/type/topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | search-menu/results/type/topic",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows PM icon for PM topic in regular search", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const pmTopic = store.createRecord("topic", {
        id: 1,
        title: "Private Message Topic",
        archetype: "private_message",
      });

      await render(
        <template>
          <TopicResultComponent
            @result={{hash topic=pmTopic}}
            @isPMOnly={{false}}
          />
        </template>
      );

      assert
        .dom(".topic-status .d-icon-envelope")
        .exists("PM icon shows for PM topic in regular search");
    });

    test("hides PM icon for PM topic in PM-only search", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const pmTopic = store.createRecord("topic", {
        id: 2,
        title: "Private Message Topic 2",
        archetype: "private_message",
      });

      await render(
        <template>
          <TopicResultComponent
            @result={{hash topic=pmTopic}}
            @isPMOnly={{true}}
          />
        </template>
      );

      assert
        .dom(".topic-status .d-icon-envelope")
        .doesNotExist("PM icon hidden for PM topic in PM-only search");
    });

    test("does not show PM icon for regular topic", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const regularTopic = store.createRecord("topic", {
        id: 3,
        title: "Regular Topic",
        archetype: "regular",
      });

      await render(
        <template>
          <TopicResultComponent
            @result={{hash topic=regularTopic}}
            @isPMOnly={{false}}
          />
        </template>
      );

      assert
        .dom(".topic-status .d-icon-envelope")
        .doesNotExist("PM icon not shown for regular topic");
    });
  }
);
