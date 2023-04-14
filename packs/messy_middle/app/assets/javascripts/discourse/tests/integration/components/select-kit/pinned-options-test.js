import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { getOwner } from "discourse-common/lib/get-owner";

module("Integration | Component | select-kit/pinned-options", function (hooks) {
  setupRenderingTest(hooks);

  test("unpinning", async function (assert) {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("subject", selectKit());

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
      hbs`<PinnedOptions @value={{this.topic.pinned}} @topic={{this.topic}} />`
    );

    assert.strictEqual(this.subject.header().name(), "pinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("unpinned");

    assert.strictEqual(this.subject.header().name(), "unpinned");
  });

  test("pinning", async function (assert) {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("subject", selectKit());
    const store = getOwner(this).lookup("service:store");
    this.set(
      "topic",
      store.createRecord("topic", {
        id: 1234,
        title: "Qunit Test Topic",
        deleted_at: new Date(),
        pinned: false,
      })
    );

    await render(
      hbs`<PinnedOptions @value={{this.topic.pinned}} @topic={{this.topic}} />`
    );

    assert.strictEqual(this.subject.header().name(), "unpinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("pinned");

    assert.strictEqual(this.subject.header().name(), "pinned");
  });
});
