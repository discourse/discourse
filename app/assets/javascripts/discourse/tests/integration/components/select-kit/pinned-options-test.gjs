import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import PinnedOptions from "select-kit/components/pinned-options";

module("Integration | Component | select-kit/pinned-options", function (hooks) {
  setupRenderingTest(hooks);

  test("unpinning", async function (assert) {
    const self = this;

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
      <template>
        <PinnedOptions @value={{self.topic.pinned}} @topic={{self.topic}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "pinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("unpinned");

    assert.strictEqual(this.subject.header().name(), "unpinned");
  });

  test("pinning", async function (assert) {
    const self = this;

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
      <template>
        <PinnedOptions @value={{self.topic.pinned}} @topic={{self.topic}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "unpinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("pinned");

    assert.strictEqual(this.subject.header().name(), "pinned");
  });
});
