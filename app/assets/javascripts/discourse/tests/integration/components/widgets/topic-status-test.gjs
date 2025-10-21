import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | topic-status", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.deactivate_widgets_rendering = false;
  });

  test("basics", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const args = {
      topic: store.createRecord("topic", { closed: true }),
      disableActions: true,
    };

    await render(
      <template><MountWidget @widget="topic-status" @args={{args}} /></template>
    );

    assert.dom(".topic-status [class*='d-icon-topic.closed']").exists();
  });

  test("toggling pin status", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const args = {
      topic: store.createRecord("topic", { closed: true, pinned: true }),
    };

    await render(
      <template><MountWidget @widget="topic-status" @args={{args}} /></template>
    );

    assert.dom(".topic-statuses .pinned").exists("pinned icon is shown");
    assert
      .dom(".topic-statuses .unpinned")
      .doesNotExist("unpinned icon is not shown");

    await click(".topic-statuses a.pin-toggle-button");

    assert
      .dom(".topic-statuses .pinned")
      .doesNotExist("pinned icon is not shown");
    assert.dom(".topic-statuses .unpinned").exists("unpinned icon is shown");

    await click(".topic-statuses a.pin-toggle-button");

    assert.dom(".topic-statuses .pinned").exists("pinned icon is shown");
    assert
      .dom(".topic-statuses .unpinned")
      .doesNotExist("unpinned icon is not shown");
  });
});
