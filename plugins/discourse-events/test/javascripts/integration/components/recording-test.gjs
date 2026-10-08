import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Recording from "../../discourse/components/discourse-post-event/recording";

module(
  "Integration | Component | DiscoursePostEvent::Recording",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.event = {
        livestream: true,
        isExpired: true,
        canActOnDiscoursePostEvent: true,
        recordingUrl: null,
      };
    });

    test("links to the recording for everyone once it exists", async function (assert) {
      this.event.canActOnDiscoursePostEvent = false;
      this.event.recordingUrl = "youtu.be/abc";

      await render(<template><Recording @event={{this.event}} /></template>);

      assert
        .dom(".event-recording__watch")
        .hasAttribute("href", "https://youtu.be/abc")
        .hasAttribute("target", "_blank")
        .hasText("Watch recording");
      assert.dom(".event-recording__add").doesNotExist();
    });

    test("embeds the recording when it has a onebox", async function (assert) {
      this.event.recordingUrl = "https://example.com/recording";
      this.event.recordingOnebox =
        '<aside class="onebox recording-onebox">Recording</aside>';

      await render(<template><Recording @event={{this.event}} /></template>);

      assert.dom(".event-recording .recording-onebox").exists();
      assert.dom(".event-recording__watch").doesNotExist();
    });

    test("prompts an editor to add a recording after a livestream ends", async function (assert) {
      await render(<template><Recording @event={{this.event}} /></template>);

      assert.dom(".event-recording__add").hasText("Add recording link");
    });

    test("does not prompt users who can't edit the event", async function (assert) {
      this.event.canActOnDiscoursePostEvent = false;

      await render(<template><Recording @event={{this.event}} /></template>);

      assert.dom(".event-recording").doesNotExist();
    });

    test("does not prompt before the event has ended", async function (assert) {
      this.event.isExpired = false;

      await render(<template><Recording @event={{this.event}} /></template>);

      assert.dom(".event-recording").doesNotExist();
    });

    test("does not prompt for events that weren't livestreamed", async function (assert) {
      this.event.livestream = false;

      await render(<template><Recording @event={{this.event}} /></template>);

      assert.dom(".event-recording").doesNotExist();
    });
  }
);
