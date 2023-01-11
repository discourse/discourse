import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { getOwner } from "discourse-common/lib/get-owner";

module("Integration | Component | Widget | topic-status", function (hooks) {
  setupRenderingTest(hooks);

  test("basics", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    this.set("args", {
      topic: store.createRecord("topic", { closed: true }),
      disableActions: true,
    });

    await render(
      hbs`<MountWidget @widget="topic-status" @args={{this.args}} />`
    );

    assert.ok(exists(".topic-status .d-icon-lock"));
  });

  test("extendability", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    TopicStatusIcons.addObject([
      "has_accepted_answer",
      "far-check-square",
      "solved",
    ]);
    this.set("args", {
      topic: store.createRecord("topic", {
        has_accepted_answer: true,
      }),
      disableActions: true,
    });

    await render(
      hbs`<MountWidget @widget="topic-status" @args={{this.args}} />`
    );

    assert.ok(exists(".topic-status .d-icon-far-check-square"));
  });

  test("toggling pin status", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    this.set("args", {
      topic: store.createRecord("topic", { closed: true, pinned: true }),
    });

    await render(
      hbs`<MountWidget @widget="topic-status" @args={{this.args}} />`
    );

    assert.ok(exists(".topic-statuses .pinned"), "pinned icon is shown");
    assert.ok(
      !exists(".topic-statuses .unpinned"),
      "unpinned icon is not shown"
    );

    await click(".topic-statuses .pin-toggle-button");

    assert.ok(!exists(".topic-statuses .pinned"), "pinned icon is not shown");
    assert.ok(exists(".topic-statuses .unpinned"), "unpinned icon is shown");

    await click(".topic-statuses .pin-toggle-button");

    assert.ok(exists(".topic-statuses .pinned"), "pinned icon is shown");
    assert.ok(
      !exists(".topic-statuses .unpinned"),
      "unpinned icon is not shown"
    );
  });
});
