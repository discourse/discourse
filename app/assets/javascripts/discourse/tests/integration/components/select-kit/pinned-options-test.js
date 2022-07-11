import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import Topic from "discourse/models/topic";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const buildTopic = function (pinned = true) {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic",
    deleted_at: new Date(),
    pinned,
  });
};

module("Integration | Component | select-kit/pinned-options", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("unpinning", async function (assert) {
    this.siteSettings.automatically_unpin_topics = false;
    this.set("topic", buildTopic());

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
    this.set("topic", buildTopic(false));

    await render(
      hbs`<PinnedOptions @value={{this.topic.pinned}} @topic={{this.topic}} />`
    );

    assert.strictEqual(this.subject.header().name(), "unpinned");

    await this.subject.expand();
    await this.subject.selectRowByValue("pinned");

    assert.strictEqual(this.subject.header().name(), "pinned");
  });
});
