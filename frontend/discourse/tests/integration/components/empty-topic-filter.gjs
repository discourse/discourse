import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmptyTopicFilter from "discourse/components/empty-topic-filter";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | EmptyTopicFilter", function (hooks) {
  setupRenderingTest(hooks);

  test("renders new education text when newFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{false}} @newFilter={{true}} />
      </template>
    );

    assert
      .dom(".empty-topic-filter__text")
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
      .dom(".empty-topic-filter__text")
      .hasText(i18n("topics.none.education.new_new"));
  });

  test("renders unread education text when unreadFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{true}} @newFilter={{false}} />
      </template>
    );

    assert
      .dom(".empty-topic-filter__text")
      .hasText(i18n("topics.none.education.unread"));
  });

  test("renders generic education text when neither newFilter nor unreadFilter is true", async function (assert) {
    await render(
      <template>
        <EmptyTopicFilter @unreadFilter={{false}} @newFilter={{false}} />
      </template>
    );

    assert
      .dom(".empty-topic-filter__text")
      .hasText(i18n("topics.none.education.generic"));
  });
});
