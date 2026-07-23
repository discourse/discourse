import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Location from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/location";

module(
  "Integration | Component | DiscoursePostEventLocation",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders server-rendered links and opens them in a new tab", async function (assert) {
      await render(
        <template>
          <Location
            @locationHtml='<a href="https://zoom.us/j/123" rel="nofollow ugc">RSVP</a> (room 2)'
          />
        </template>
      );

      assert
        .dom(".event-location a")
        .hasAttribute("href", "https://zoom.us/j/123")
        .hasAttribute("target", "_blank")
        .hasAttribute("rel", "nofollow ugc noopener")
        .hasText("RSVP", "shows the link label");
      assert
        .dom(".event-location")
        .includesText("(room 2)", "keeps the text around the link");
    });

    test("renders nothing without a location", async function (assert) {
      await render(<template><Location /></template>);

      assert.dom(".event-location").doesNotExist();
    });
  }
);
