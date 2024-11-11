import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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

    assert.dom(".topic-status .d-icon-lock").exists();
  });

  test("extendability", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    TopicStatusIcons.addObject([
      "has_accepted_answer",
      "far-square-check",
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

    assert.dom(".topic-status .d-icon-far-square-check").exists();
  });

  test("toggling pin status", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    this.set("args", {
      topic: store.createRecord("topic", { closed: true, pinned: true }),
    });

    await render(
      hbs`<MountWidget @widget="topic-status" @args={{this.args}} />`
    );

    assert.dom(".topic-statuses .pinned").exists("pinned icon is shown");
    assert
      .dom(".topic-statuses .unpinned")
      .doesNotExist("unpinned icon is not shown");

    await click(".topic-statuses .pin-toggle-button");

    assert
      .dom(".topic-statuses .pinned")
      .doesNotExist("pinned icon is not shown");
    assert.dom(".topic-statuses .unpinned").exists("unpinned icon is shown");

    await click(".topic-statuses .pin-toggle-button");

    assert.dom(".topic-statuses .pinned").exists("pinned icon is shown");
    assert
      .dom(".topic-statuses .unpinned")
      .doesNotExist("unpinned icon is not shown");
  });
});
