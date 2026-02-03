import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmptyTopicFilter from "discourse/components/empty-topic-filter";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | EmptyTopicFilter", function (hooks) {
  setupRenderingTest(hooks);

  test("renders empty state with CTA when viewing topics with available replies", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.trackingCounts = { newReplies: 5, newTopics: 0 };
    this.newListSubset = "topics";
    this.actionCalled = false;
    this.changeNewListSubset = () => {
      this.set("actionCalled", true);
    };

    await render(
      <template>
        <EmptyTopicFilter
          @newFilter={{true}}
          @newListSubset={{this.newListSubset}}
          @trackingCounts={{this.trackingCounts}}
          @changeNewListSubset={{this.changeNewListSubset}}
        />
      </template>
    );

    assert.dom(".empty-state__cta button").exists("CTA button is rendered");
    assert
      .dom(".empty-state__cta button")
      .hasText(/replies/i, "CTA suggests browsing replies");

    await click(".empty-state__cta button");
    assert.true(this.actionCalled, "action is called when button is clicked");
  });

  test("renders empty state with CTA when viewing replies with available topics", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.trackingCounts = { newReplies: 0, newTopics: 5 };
    this.newListSubset = "replies";
    this.actionCalled = false;
    this.changeNewListSubset = () => {
      this.set("actionCalled", true);
    };

    await render(
      <template>
        <EmptyTopicFilter
          @newFilter={{true}}
          @newListSubset={{this.newListSubset}}
          @trackingCounts={{this.trackingCounts}}
          @changeNewListSubset={{this.changeNewListSubset}}
        />
      </template>
    );

    assert.dom(".empty-state__cta button").exists("CTA button is rendered");
    assert
      .dom(".empty-state__cta button")
      .hasText(/topics/i, "CTA suggests browsing topics");

    await click(".empty-state__cta button");
    assert.true(this.actionCalled, "action is called when button is clicked");
  });

  test("renders empty state with discovery.latest link when no alternative content available", async function (assert) {
    this.currentUser.new_new_view_enabled = true;
    this.trackingCounts = { newReplies: 0, newTopics: 0 };
    this.newListSubset = "topics";
    this.changeNewListSubset = () => {};

    await render(
      <template>
        <EmptyTopicFilter
          @newFilter={{true}}
          @newListSubset={{this.newListSubset}}
          @trackingCounts={{this.trackingCounts}}
          @changeNewListSubset={{this.changeNewListSubset}}
        />
      </template>
    );

    assert.dom(".empty-state__cta button").exists("CTA button is rendered");
    assert
      .dom(".empty-state__cta button")
      .hasText(/latest/i, "CTA links to latest topics");
  });

  test("renders empty state with discovery.latest link when new_new_view is disabled", async function (assert) {
    this.currentUser.new_new_view_enabled = false;
    this.trackingCounts = { newReplies: 5, newTopics: 0 };
    this.newListSubset = "topics";
    this.changeNewListSubset = () => {};

    await render(
      <template>
        <EmptyTopicFilter
          @newFilter={{true}}
          @newListSubset={{this.newListSubset}}
          @trackingCounts={{this.trackingCounts}}
          @changeNewListSubset={{this.changeNewListSubset}}
        />
      </template>
    );

    assert.dom(".empty-state__cta button").exists("CTA button is rendered");
    assert
      .dom(".empty-state__cta button")
      .hasText(/latest/i, "CTA links to latest topics");
  });

  test("renders empty state for unread filter", async function (assert) {
    this.currentUser.new_new_view_enabled = false;

    await render(
      <template><EmptyTopicFilter @unreadFilter={{true}} /></template>
    );

    assert.dom(".empty-state").exists("empty state is rendered");
    assert.dom(".empty-state__cta button").exists("CTA button is rendered");
  });

  test("renders new education text when newFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{false}} @newFilter={{true}} />
      </template>
    );

    assert
      .dom(".empty-state__title")
      .hasText(i18n("topics.none.education.new"));
  });

  test("renders new_new education text when newFilter is true and new_new_view_enabled", async function (assert) {
    this.currentUser.new_new_view_enabled = true;

    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{false}} @newFilter={{true}} />
      </template>
    );

    assert
      .dom(".empty-state__title")
      .hasText(i18n("topics.none.education.new_new"));
  });

  test("renders unread education text when unreadFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{true}} @newFilter={{false}} />
      </template>
    );

    assert
      .dom(".empty-state__title")
      .hasText(i18n("topics.none.education.unread"));
  });

  test("renders generic education text when neither newFilter nor unreadFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{false}} @newFilter={{false}} />
      </template>
    );

    assert
      .dom(".empty-state__title")
      .hasText(i18n("topics.none.education.generic"));
  });
});
