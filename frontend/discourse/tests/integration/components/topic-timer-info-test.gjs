import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-timer-info", function (hooks) {
  setupRenderingTest(hooks);

  test("does not crash when category does not exist in client cache", async function (assert) {
    const executeAt = moment().add(2, "days").toISOString();

    await render(
      <template>
        <TopicTimerInfo
          @statusType="publish_to_category"
          @executeAt={{executeAt}}
          @categoryId={{99999}}
        />
      </template>
    );

    assert.dom(".topic-timer-heading").exists();
  });

  test("displays delete after last post notice when basedOnLastPost is true", async function (assert) {
    const executeAt = moment().add(2, "days").toISOString();

    await render(
      <template>
        <TopicTimerInfo
          @statusType="delete"
          @basedOnLastPost={{true}}
          @executeAt={{executeAt}}
          @durationMinutes={{2880}}
        />
      </template>
    );

    assert
      .dom(".topic-timer-heading")
      .matchesText(/will be deleted.*after the last reply/);
  });
});
