import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LiveParticipantSidebarSuffix from "discourse/plugins/live/discourse/components/live-participant-sidebar-suffix";

module(
  "Integration | Component | live-participant-sidebar-suffix",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders every applicable state icon simultaneously", async function (assert) {
      const suffixArgs = {
        isScreenSharing: true,
        isVideoOn: true,
        isPtt: false,
        isMuted: true,
        isDeafened: true,
      };

      await render(
        <template>
          <LiveParticipantSidebarSuffix @suffixArgs={{suffixArgs}} />
        </template>
      );

      assert.dom(".live-participant-suffix .d-icon-display").exists();
      assert.dom(".live-participant-suffix .d-icon-video").exists();
      assert.dom(".live-participant-suffix .d-icon-microphone-slash").exists();
      assert.dom(".live-participant-suffix .d-icon-volume-xmark").exists();
    });

    test("renders the wrapper even with no active states", async function (assert) {
      const suffixArgs = {
        isScreenSharing: false,
        isVideoOn: false,
        isPtt: false,
        isMuted: false,
        isDeafened: false,
      };

      await render(
        <template>
          <LiveParticipantSidebarSuffix @suffixArgs={{suffixArgs}} />
        </template>
      );

      assert.dom(".live-participant-suffix").exists();
      assert.dom(".live-participant-suffix .d-icon").doesNotExist();
    });
  }
);
