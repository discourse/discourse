import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | modal/dismiss-new", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.model = { selectedTopics: [] };
  });

  test("modal title", async function (assert) {
    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert
      .dom("#discourse-modal-title")
      .hasText(i18n("topics.bulk.dismiss_new_modal.title"));
  });

  test("default state", async function (assert) {
    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert.dom(".dismiss-topics input").isChecked();
    assert.dom(".dismiss-posts input").isChecked();
    assert.dom(".untrack input").isNotChecked();
  });

  test("one new selected topic", async function (assert) {
    this.model.selectedTopics.push({
      id: 1,
      title: "Topic 1",
      unread_posts: false,
    });

    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert.dom(".dismiss-posts").doesNotExist();
    assert
      .dom(".dismiss-topics")
      .hasText(
        i18n("topics.bulk.dismiss_new_modal.topics_with_count", { count: 1 })
      );
  });

  test("one new unread in selected topic", async function (assert) {
    this.model.selectedTopics.push({
      id: 1,
      title: "Topic 1",
      unread_posts: true,
    });

    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert.dom(".dismiss-topics").doesNotExist();
    assert
      .dom(".dismiss-posts")
      .hasText(
        i18n("topics.bulk.dismiss_new_modal.replies_with_count", { count: 1 })
      );
  });

  test("no selected topics with topics subset", async function (assert) {
    this.model.subset = "topics";

    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert.dom(".dismiss-posts").doesNotExist();
    assert
      .dom(".dismiss-topics")
      .hasText(i18n("topics.bulk.dismiss_new_modal.topics"));
  });

  test("no selected topics with replies subset", async function (assert) {
    this.model.subset = "replies";

    await render(
      hbs`<Modal::DismissNew @inline={{true}} @model={{this.model}} />`
    );

    assert.dom(".dismiss-topics").doesNotExist();
    assert
      .dom(".dismiss-posts")
      .hasText(i18n("topics.bulk.dismiss_new_modal.replies"));
  });

  test("dismissed", async function (assert) {
    let state;

    this.model.dismissCallback = (newState) => {
      state = newState;
    };

    this.noop = () => {};

    await render(
      hbs`<Modal::DismissNew @closeModal={{this.noop}} @inline={{true}} @model={{this.model}} />`
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
