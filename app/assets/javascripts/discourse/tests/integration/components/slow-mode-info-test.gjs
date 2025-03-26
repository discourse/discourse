import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SlowModeInfo from "discourse/components/slow-mode-info";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | slow-mode-info", function (hooks) {
  setupRenderingTest(hooks);

  test("doesn't render if the topic is closed", async function (assert) {
    const self = this;

    this.set("topic", { slow_mode_seconds: 3600, closed: true });

    await render(<template><SlowModeInfo @topic={{self.topic}} /></template>);

    assert.dom(".slow-mode-heading").doesNotExist("doesn't render the notice");
  });

  test("doesn't render if the slow mode is disabled", async function (assert) {
    const self = this;

    this.set("topic", { slow_mode_seconds: 0, closed: false });

    await render(<template><SlowModeInfo @topic={{self.topic}} /></template>);

    assert.dom(".slow-mode-heading").doesNotExist("doesn't render the notice");
  });

  test("renders if slow mode is enabled", async function (assert) {
    const self = this;

    this.set("topic", { slow_mode_seconds: 3600, closed: false });

    await render(<template><SlowModeInfo @topic={{self.topic}} /></template>);

    assert.dom(".slow-mode-heading").exists();
  });

  test("staff and TL4 users can disable slow mode", async function (assert) {
    const self = this;

    this.setProperties({
      topic: { slow_mode_seconds: 3600, closed: false },
      user: { canManageTopic: true },
    });

    await render(
      <template>
        <SlowModeInfo @topic={{self.topic}} @user={{self.user}} />
      </template>
    );

    assert.dom(".slow-mode-remove").exists();
  });

  test("regular users can't disable slow mode", async function (assert) {
    const self = this;

    this.setProperties({
      topic: { slow_mode_seconds: 3600, closed: false },
      user: { canManageTopic: false },
    });

    await render(
      <template>
        <SlowModeInfo @topic={{self.topic}} @user={{self.user}} />
      </template>
    );

    assert
      .dom(".slow-mode-remove")
      .doesNotExist("doesn't let you disable slow mode");
  });
});
