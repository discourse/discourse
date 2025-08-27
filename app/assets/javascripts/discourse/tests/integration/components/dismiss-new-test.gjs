import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DismissNew from "discourse/components/modal/dismiss-new";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | modal/dismiss-new", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.model = { selectedTopics: [] };
  });

  test("modal title", async function (assert) {
    const self = this;

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert
      .dom("#discourse-modal-title")
      .hasText(i18n("topics.bulk.dismiss_new_modal.title"));
  });

  test("default state", async function (assert) {
    const self = this;

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert.dom(".dismiss-topics input").isChecked();
    assert.dom(".dismiss-posts input").isChecked();
    assert.dom(".untrack input").isNotChecked();
  });

  test("one new selected topic", async function (assert) {
    const self = this;

    this.model.selectedTopics.push({
      id: 1,
      title: "Topic 1",
      unread_posts: false,
    });

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert.dom(".dismiss-posts").doesNotExist();
    assert
      .dom(".dismiss-topics")
      .hasText(
        i18n("topics.bulk.dismiss_new_modal.topics_with_count", { count: 1 })
      );
  });

  test("one new unread in selected topic", async function (assert) {
    const self = this;

    this.model.selectedTopics.push({
      id: 1,
      title: "Topic 1",
      unread_posts: true,
    });

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert.dom(".dismiss-topics").doesNotExist();
    assert
      .dom(".dismiss-posts")
      .hasText(
        i18n("topics.bulk.dismiss_new_modal.replies_with_count", { count: 1 })
      );
  });

  test("selected replies unchecked with topics subset", async function (assert) {
    const self = this;

    this.model.subset = "topics";

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert.dom(".dismiss-posts").isNotChecked();
    assert
      .dom(".dismiss-topics")
      .hasText(i18n("topics.bulk.dismiss_new_modal.topics"));
  });

  test("selected topics unchecked with replies subset", async function (assert) {
    const self = this;

    this.model.subset = "replies";

    await render(
      <template><DismissNew @inline={{true}} @model={{self.model}} /></template>
    );

    assert.dom(".dismiss-topics").isNotChecked();
    assert
      .dom(".dismiss-posts")
      .hasText(i18n("topics.bulk.dismiss_new_modal.replies"));
  });

  test("dismissed", async function (assert) {
    const self = this;

    let state;

    this.model.dismissCallback = (newState) => {
      state = newState;
    };

    this.noop = () => {};

    await render(
      <template>
        <DismissNew
          @closeModal={{self.noop}}
          @inline={{true}}
          @model={{self.model}}
        />
      </template>
    );

    await click(".dismiss-topics [type='checkbox']");
    await click(".dismiss-posts [type='checkbox']");
    await click(".untrack [type='checkbox']");
    await click("#dismiss-read-confirm");

    assert.false(state.dismissTopics);
    assert.false(state.dismissPosts);
    assert.true(state.untrack);
  });
});
