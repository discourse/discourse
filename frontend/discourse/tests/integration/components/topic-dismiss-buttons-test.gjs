import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | topic-dismiss-buttons", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.model = {
      topics: [{}],
      params: {},
    };
    this.selectedTopics = [];
    this.showResetNew = true;
    this.showNewDismissCombo = false;
    this.resetNewCalls = [];
    this.resetNew = (options) => this.resetNewCalls.push(options);
  });

  test("renders a direct dismiss all combo button in the experimental new view", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.showNewDismissCombo = true;

    await render(
      <template>
        <TopicDismissButtons
          @position="top"
          @model={{this.model}}
          @selectedTopics={{this.selectedTopics}}
          @showResetNew={{this.showResetNew}}
          @showNewDismissCombo={{this.showNewDismissCombo}}
          @showDismissRead={{false}}
          @resetNew={{this.resetNew}}
        />
      </template>
    );

    assert.dom("#dismiss-new-top").hasText(i18n("topics.bulk.dismiss_all"));
    assert.dom("#dismiss-new-menu-top").exists();
  });

  test("dismisses the active subset directly in the experimental new view", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.showNewDismissCombo = true;
    this.model.params.subset = "replies";

    await render(
      <template>
        <TopicDismissButtons
          @position="top"
          @model={{this.model}}
          @selectedTopics={{this.selectedTopics}}
          @showResetNew={{this.showResetNew}}
          @showNewDismissCombo={{this.showNewDismissCombo}}
          @showDismissRead={{false}}
          @resetNew={{this.resetNew}}
        />
      </template>
    );

    assert
      .dom("#dismiss-new-top")
      .hasText(i18n("topics.bulk.dismiss_new_replies"));

    await click("#dismiss-new-top");

    assert.deepEqual(this.resetNewCalls, [
      {
        dismissPosts: true,
        dismissTopics: false,
        untrack: false,
      },
    ]);
  });

  test("dismiss and stop tracking runs the same subset with untrack enabled", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.showNewDismissCombo = true;
    this.model.params.subset = "topics";

    await render(
      <template>
        <TopicDismissButtons
          @position="top"
          @model={{this.model}}
          @selectedTopics={{this.selectedTopics}}
          @showResetNew={{this.showResetNew}}
          @showNewDismissCombo={{this.showNewDismissCombo}}
          @showDismissRead={{false}}
          @resetNew={{this.resetNew}}
        />
      </template>
    );

    await click("#dismiss-new-menu-top");

    assert
      .dom(".fk-d-menu .dismiss-new-stop-tracking .d-button-label")
      .hasText(i18n("topics.bulk.dismiss_and_stop_tracking"));

    await click(".fk-d-menu .dismiss-new-stop-tracking");

    assert.deepEqual(this.resetNewCalls, [
      {
        dismissPosts: false,
        dismissTopics: true,
        untrack: true,
      },
    ]);
  });

  test("keeps the legacy dismiss new button outside the experimental new view", async function (assert) {
    await render(
      <template>
        <TopicDismissButtons
          @position="top"
          @model={{this.model}}
          @selectedTopics={{this.selectedTopics}}
          @showResetNew={{this.showResetNew}}
          @showNewDismissCombo={{this.showNewDismissCombo}}
          @showDismissRead={{false}}
          @resetNew={{this.resetNew}}
        />
      </template>
    );

    assert.dom("#dismiss-new-top").hasText(i18n("topics.bulk.dismiss_new"));
    assert.dom("#dismiss-new-menu-top").doesNotExist();
  });
});
