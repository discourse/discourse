import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmptyTopic from "discourse/components/empty-topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | empty-topic", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the correct education text based on unread or new", async function (assert) {
    await render(
      <template>
        <EmptyTopic @unreadFilter={{false}} @newFilter={{true}} />
      </template>
    );

    assert.dom(".empty-topic__text").hasText(i18n("topics.none.education.new"));

    this.siteSettings.new_new_view_enabled = true;

    await render(
      <template>
        <EmptyTopic @unreadFilter={{false}} @newFilter={{true}} />
      </template>
    );

    assert
      .dom(".empty-topic__text")
      .hasText(i18n("topics.none.education.new_new"));

    await render(
      <template>
        <EmptyTopic @unreadFilter={{true}} @newFilter={{false}} />
      </template>
    );

    assert
      .dom(".empty-topic__text")
      .hasText(i18n("topics.none.education.unread"));
  });
});
