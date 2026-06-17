import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomEntry from "../../discourse/components/livestream/zoom-entry";

module("Integration | Component | LivestreamZoomEntry", function (hooks) {
  setupRenderingTest(hooks);

  function stubCapabilities(owner, viewport) {
    owner.unregister("service:capabilities");
    owner.register(
      "service:capabilities",
      {
        viewport,
      },
      { instantiate: false }
    );
  }

  hooks.beforeEach(function () {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.livestream_enabled = true;
    siteSettings.livestream_zoom_enabled = true;
  });

  test("renders the inline join button on desktop", async function (assert) {
    stubCapabilities(getOwner(this), { lg: true });

    this.topic = { id: 1, slug: "test-topic", chat_channel_id: 9 };
    this.zoomUrl = "https://us06web.zoom.us/j/123456789?pwd=secret";

    await render(
      <template>
        <LivestreamZoomEntry @topic={{this.topic}} @zoomUrl={{this.zoomUrl}} />
      </template>
    );

    assert
      .dom(".discourse-calendar-livestream-zoom-entry .btn-primary")
      .hasText("Join Zoom");
    assert.dom(".discourse-calendar-livestream-zoom-entry__frame").exists();
  });

  test("renders the mobile route link on mobile", async function (assert) {
    stubCapabilities(getOwner(this), { lg: false });

    this.topic = { id: 1, slug: "test-topic", chat_channel_id: 9 };
    this.zoomUrl = "https://us06web.zoom.us/j/123456789?pwd=secret";

    await render(
      <template>
        <LivestreamZoomEntry @topic={{this.topic}} @zoomUrl={{this.zoomUrl}} />
      </template>
    );

    assert
      .dom(
        '.discourse-calendar-livestream-zoom-entry a[href="/t/test-topic/1/zoom"]'
      )
      .exists();
  });
});
