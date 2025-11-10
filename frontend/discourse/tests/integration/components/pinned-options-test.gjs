import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PinnedOptions from "discourse/components/pinned-options";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | pinned-options", function (hooks) {
  setupRenderingTest(hooks);

  test("unpinning", async function (assert) {
    this.siteSettings.automatically_unpin_topics = false;

    const store = getOwner(this).lookup("service:store");
    this.set(
      "topic",
      store.createRecord("topic", {
        id: 1234,
        title: "Qunit Test Topic",
        deleted_at: new Date(),
        pinned: true,
      })
    );

    await render(
      <template>
        <PinnedOptions @value={{this.topic.pinned}} @topic={{this.topic}} />
      </template>
    );

    assert.dom(".pinned-options-trigger-btn .d-button-label").hasText("Pinned");

    await click(".pinned-options-trigger-btn");

    await click('[data-pinned-state="unpinned"]');

    assert.false(this.topic.pinned, "topic should be unpinned");
    assert.true(this.topic.unpinned, "topic should be marked as unpinned");
  });

  test("pinning", async function (assert) {
    this.siteSettings.automatically_unpin_topics = false;

    const store = getOwner(this).lookup("service:store");
    this.set(
      "topic",
      store.createRecord("topic", {
        id: 1234,
        title: "Qunit Test Topic",
        deleted_at: new Date(),
        pinned: false,
        unpinned: true,
      })
    );

    await render(
      <template>
        <PinnedOptions @value={{this.topic.pinned}} @topic={{this.topic}} />
      </template>
    );

    assert
      .dom(".pinned-options-trigger-btn .d-button-label")
      .hasText("Unpinned");

    await click(".pinned-options-trigger-btn");

    await click('[data-pinned-state="pinned"]');

    assert.true(this.topic.pinned, "topic is pinned");
    assert.false(this.topic.unpinned, "topic isn't unpinned");
  });
});
