import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | topic-status", function (hooks) {
  setupRenderingTest(hooks);

  test("basics", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const args = {
      topic: store.createRecord("topic", { closed: true }),
      disableActions: true,
    };

    await render(<template>
      <MountWidget @widget="topic-status" @args={{args}} />
    </template>);

    assert.dom(".topic-status .d-icon-lock").exists();
  });

  test("extendability", async function (assert) {
    this.siteSettings.glimmer_topic_list_mode = "disabled";
    withSilencedDeprecations("discourse.hbr-topic-list-overrides", () => {
      TopicStatusIcons.addObject([
        "has_accepted_answer",
        "far-square-check",
        "solved",
      ]);
    });

    const store = getOwner(this).lookup("service:store");
    const args = {
      topic: store.createRecord("topic", { has_accepted_answer: true }),
      disableActions: true,
    };

    await render(<template>
      <MountWidget @widget="topic-status" @args={{args}} />
    </template>);

    assert.dom(".topic-status .d-icon-far-square-check").exists();
  });

  test("toggling pin status", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const args = {
      topic: store.createRecord("topic", { closed: true, pinned: true }),
    };

    await render(<template>
      <MountWidget @widget="topic-status" @args={{args}} />
    </template>);

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
